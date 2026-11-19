"""
行山腳 HikeHub · Remote-first Data Access Layer (Repository)

Responsibilities:
1. Single entry point for every INSERT / UPDATE / DELETE against Supabase.
2. Online: write to PostgREST first, verify the returned representation, then
   read the authoritative counter back. A rejected write is never reported as
   success (RLS denials can silently return an empty result set).
3. Offline (`remote_online == False`): return `WriteResult(offline=True)` so the
   service layer can persist to the local JSON mirror and label the UI as
   「離線演示模式」. No network call is attempted.
4. `sync_mirror()` fetches all 9 tables in one pass, re-assembles `post_photos`
   into `posts[].photos`, and atomically replaces the local mirror so every
   `_enrich_post` / `list_trails` reader sees cloud truth.

Security: error messages are sanitised so anon keys, JWTs, URLs and passwords
never reach the UI or the console.
"""
from __future__ import annotations

import re
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

from app.backend.supabase_client import get_db, recompute_counts

MIRROR_TABLES: Tuple[str, ...] = (
    "profiles",
    "trails",
    "trail_segments",
    "checkpoints",
    "posts",
    "post_photos",
    "comments",
    "likes",
    "favorites",
)

OFFLINE_HINT = "離線演示，資料僅存本機"

_URL_RE = re.compile(r"https?://\S+")
_JWT_RE = re.compile(r"eyJ[A-Za-z0-9_\-\.]+")
_WS_RE = re.compile(r"\s+")


@dataclass
class WriteResult:
    """Structured outcome of a repository write."""

    ok: bool
    data: Optional[Dict[str, Any]] = None
    offline: bool = False
    error: str = ""


def _safe_error(exc: BaseException) -> str:
    """Human-readable error with every credential-ish token stripped out."""
    raw = str(getattr(exc, "message", exc) or "").strip()
    clean = _JWT_RE.sub("", _URL_RE.sub("", raw))
    clean = _WS_RE.sub(" ", clean).strip(" ,;:-")
    if not clean:
        clean = exc.__class__.__name__
    code = getattr(exc, "code", None)
    if code and str(code) not in clean:
        clean = f"{clean} ({code})"
    return clean[:180]


class RemoteStore:
    def __init__(self, db: Optional[Any] = None) -> None:
        self.db = db or get_db()
        self._sync_in_flight = False

    @property
    def online(self) -> bool:
        return bool(self.db.remote_online and self.db.client is not None)

    @property
    def sync_in_flight(self) -> bool:
        return self._sync_in_flight

    def mark_sync_in_flight(self) -> None:
        """Reserve the sync slot before starting the background worker."""
        self._sync_in_flight = True

    # ------------------------------------------------------------------
    # Remote CRUD (online-first; every failure is explicit)
    # ------------------------------------------------------------------
    def insert(self, table: str, payload: Dict[str, Any]) -> WriteResult:
        if not self.online:
            return WriteResult(ok=True, offline=True, data=dict(payload))
        try:
            res = self.db.client.table(table).insert(payload).execute()
            rows = list(getattr(res, "data", None) or [])
            if not rows:
                return WriteResult(
                    ok=False,
                    error="雲端未寫入任何資料（可能被權限規則拒絕）",
                )
            return WriteResult(ok=True, data=rows[0])
        except Exception as exc:
            return WriteResult(ok=False, error=_safe_error(exc))

    def update(
        self, table: str, payload: Dict[str, Any], **eq_filters: Any
    ) -> WriteResult:
        if not self.online:
            return WriteResult(ok=True, offline=True, data=dict(payload))
        try:
            query = self.db.client.table(table).update(payload)
            for column, value in eq_filters.items():
                query = query.eq(column, value)
            res = query.execute()
            rows = list(getattr(res, "data", None) or [])
            if not rows:
                return WriteResult(
                    ok=False,
                    error="雲端未更新任何資料（可能無權限或資料不存在）",
                )
            return WriteResult(ok=True, data=rows[0])
        except Exception as exc:
            return WriteResult(ok=False, error=_safe_error(exc))

    def delete(self, table: str, **eq_filters: Any) -> WriteResult:
        if not self.online:
            return WriteResult(ok=True, offline=True)
        try:
            query = self.db.client.table(table).delete()
            for column, value in eq_filters.items():
                query = query.eq(column, value)
            res = query.execute()
            rows = list(getattr(res, "data", None) or [])
            if not rows:
                return WriteResult(
                    ok=False,
                    error="雲端未刪除任何資料（可能無權限或資料不存在）",
                )
            return WriteResult(ok=True, data=rows[0])
        except Exception as exc:
            return WriteResult(ok=False, error=_safe_error(exc))

    def fetch_all(self, table: str) -> Optional[List[Dict[str, Any]]]:
        """Return all rows, or None when remote is unavailable / fails."""
        if not self.online:
            return None
        try:
            res = self.db.client.table(table).select("*").limit(5000).execute()
            return list(getattr(res, "data", None) or [])
        except Exception:
            return None

    def fetch_row(
        self, table: str, column: str, value: Any
    ) -> Optional[Dict[str, Any]]:
        if not self.online:
            return None
        try:
            res = (
                self.db.client.table(table)
                .select("*")
                .eq(column, value)
                .limit(1)
                .execute()
            )
            rows = list(getattr(res, "data", None) or [])
            return rows[0] if rows else None
        except Exception:
            return None

    # ------------------------------------------------------------------
    # Mirror synchronisation
    # ------------------------------------------------------------------
    def sync_mirror(self) -> bool:
        """Overwrite the local mirror with cloud truth in one bounded batch."""
        if not self.online:
            return False
        self._sync_in_flight = True
        try:
            # Total budget guards against 9 sequential per-request timeouts.
            deadline = time.monotonic() + 12.0
            fetched: Dict[str, List[Dict[str, Any]]] = {}
            for table in MIRROR_TABLES:
                if time.monotonic() > deadline:
                    return False
                rows = self.fetch_all(table)
                if rows is None:
                    return False
                fetched[table] = rows

            store: Dict[str, Any] = {name: rows for name, rows in fetched.items()}
            photos_by_post: Dict[str, List[str]] = {}
            for row in sorted(
                store["post_photos"],
                key=lambda r: (str(r.get("post_id")), int(r.get("seq") or 0)),
            ):
                storage_path = row.get("storage_path")
                if storage_path:
                    photos_by_post.setdefault(str(row.get("post_id")), []).append(
                        str(storage_path)
                    )
            for post in store["posts"]:
                post["photos"] = photos_by_post.get(str(post.get("id")), [])
            for profile in store["profiles"]:
                profile.pop("password", None)

            self.db.replace_store(store)
            return True
        finally:
            self._sync_in_flight = False

    def ensure_synced(self) -> bool:
        """One-shot retry used after sign-in if the startup sync failed."""
        if self.db.mirror_synced or not self.online or self._sync_in_flight:
            return False
        return self.sync_mirror()

    def refresh_counter(self, table: str, row_id: Any, key: str) -> int:
        """Read the trigger-maintained counter from cloud; fall back to a
        mirror recompute when offline or the read-back failed."""
        if self.online:
            row = self.fetch_row(table, "id", row_id)
            if row is not None:
                return int(row.get(key, 0) or 0)
        recompute_counts(self.db.store)
        row = self.mirror_row(table, id=row_id)
        return int((row or {}).get(key, 0) or 0)

    # ------------------------------------------------------------------
    # Local mirror helpers (used by services for both online and offline)
    # ------------------------------------------------------------------
    def mirror_add(self, table: str, row: Dict[str, Any]) -> None:
        self.db.store.setdefault(table, []).append(dict(row))

    def mirror_row(self, table: str, **eq_filters: Any) -> Optional[Dict[str, Any]]:
        for row in self.db.store.get(table, []):
            if all(row.get(column) == value for column, value in eq_filters.items()):
                return row
        return None

    def mirror_remove(self, table: str, **eq_filters: Any) -> bool:
        rows = self.db.store.setdefault(table, [])
        kept = [
            row
            for row in rows
            if not all(row.get(column) == value for column, value in eq_filters.items())
        ]
        removed = len(kept) < len(rows)
        self.db.store[table] = kept
        return removed

    def mirror_patch(
        self, table: str, payload: Dict[str, Any], **eq_filters: Any
    ) -> bool:
        found = False
        for row in self.db.store.setdefault(table, []):
            if all(row.get(column) == value for column, value in eq_filters.items()):
                row.update(payload)
                found = True
        return found


_store_singleton: Optional[RemoteStore] = None


def get_remote_store() -> RemoteStore:
    global _store_singleton
    if _store_singleton is None:
        _store_singleton = RemoteStore()
    return _store_singleton
