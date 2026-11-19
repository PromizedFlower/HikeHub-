"""
行山腳 HikeHub · Authentication & Profile Service (L3 Service Layer)
Author: Member B (App Framework & Auth)

Handles Supabase Auth sign-in/sign-out, session persistence, pre-built test
account quick-fill, and profile editing (nickname, bio, avatar_url).

Login contract:
* A server-rejected credential (wrong password / unknown account) NEVER falls
  back to the local mirror.
* Only a genuine network outage degrades to 「離線演示模式」, which is always
  reported to the UI and still validates the pre-built password.
* Plaintext passwords are never read from, or written to, the local mirror.
"""
import copy
from typing import Any, Dict, List, Optional

from app.backend.supabase_client import get_db
from app.backend.remote_store import get_remote_store, OFFLINE_HINT
from app.backend.post_service import upload_photo

# Read-only convenience constant for the login page quick-fill only.
# It is NOT a credential store and is never persisted to disk.
PRESET_PASSWORD = "HikeHub2026!"


def _classify_auth_error(exc: BaseException) -> str:
    """Distinguish a server answer (4xx) from an unreachable network."""
    status = getattr(exc, "status", None)
    if isinstance(status, int):
        return "credentials" if 400 <= status < 500 else "offline"
    code = str(getattr(exc, "code", "") or "")
    if code in (
        "invalid_credentials",
        "email_not_confirmed",
        "user_not_found",
        "weak_password",
    ):
        return "credentials"
    # GoTrue answered (AuthApiError) but without a status: stay strict.
    return "credentials" if "authapi" in exc.__class__.__name__.lower() else "offline"


class AuthService:
    def __init__(self) -> None:
        self.current_user: Optional[Dict[str, Any]] = None

    def get_env_status(self) -> Dict[str, Any]:
        return get_db().get_status_summary()

    def get_preset_accounts(self) -> List[Dict[str, str]]:
        db = get_db()
        accounts: List[Dict[str, str]] = []
        for p in db.store.get("profiles", []):
            email = p.get("email", "")
            if not email:
                continue
            accounts.append({
                "email": email,
                "password": PRESET_PASSWORD,
                "nickname": p.get("nickname", ""),
            })
        return accounts

    def sign_in(self, email: str, password: str) -> Dict[str, Any]:
        db = get_db()
        clean_email = email.strip().lower()
        clean_pwd = password.strip()
        if not clean_email or not clean_pwd:
            return {"ok": False, "error": "請輸入電郵帳號及密碼"}

        if not db.env_valid:
            return self._offline_sign_in(clean_email, clean_pwd, "未配置 .env")

        if db.remote_online and db.client is not None:
            try:
                auth_res = db.client.auth.sign_in_with_password(
                    {"email": clean_email, "password": clean_pwd}
                )
            except Exception as exc:
                if _classify_auth_error(exc) == "credentials":
                    return {"ok": False, "error": "帳號或密碼錯誤，請重新輸入"}
                return self._offline_sign_in(clean_email, clean_pwd, "雲端連線失敗")

            if auth_res and getattr(auth_res, "user", None):
                uid = str(auth_res.user.id)
                # supabase-py injects the user JWT into PostgREST automatically.
                # Pull a fresh cloud snapshot before any page reads the mirror.
                get_remote_store().ensure_synced()
                profile = self._find_or_create_profile(uid, clean_email)
                if not profile:
                    return {"ok": False, "error": "無法建立雲端個人資料，請稍後再試"}
                self.current_user = profile
                return {
                    "ok": True,
                    "user": profile,
                    "offline": False,
                    "mode": db.get_status_summary()["mode"],
                }
            return {"ok": False, "error": "雲端登入未返回使用者資料"}

        return self._offline_sign_in(clean_email, clean_pwd, "雲端尚未連線")

    def _offline_sign_in(
        self, email: str, password: str, reason: str
    ) -> Dict[str, Any]:
        db = get_db()
        matched = next(
            (
                p for p in db.store.get("profiles", [])
                if p.get("email", "").lower() == email
            ),
            None,
        )
        if not matched:
            return {"ok": False, "error": f"找不到帳號：{email}（請使用預建測試帳號）"}
        if password != PRESET_PASSWORD:
            return {
                "ok": False,
                "error": "密碼錯誤，預建測試帳號密碼統一為 HikeHub2026!",
            }
        self.current_user = copy.deepcopy(matched)
        return {
            "ok": True,
            "user": self.current_user,
            "offline": True,
            "mode": OFFLINE_HINT,
            "reason": reason,
        }

    def _find_or_create_profile(self, uid: str, email: str) -> Dict[str, Any]:
        db = get_db()
        for p in db.store.get("profiles", []):
            if p["id"] == uid or p.get("email", "").lower() == email.lower():
                return copy.deepcopy(p)

        new_prof = {
            "id": uid,
            "email": email,
            "nickname": email.split("@")[0],
            "bio": "熱愛香港山野，週末必出發行山！",
            "avatar_url": "",
            "created_at": "2026-11-03T00:00:00Z",
        }
        store = get_remote_store()
        result = store.insert("profiles", new_prof)
        if not result.ok:
            # Never report a profile the cloud refused as a successful login.
            return {}
        row = dict(result.data or new_prof)
        store.mirror_add("profiles", row)
        db.save_store()
        return copy.deepcopy(row)

    def sign_out(self) -> None:
        db = get_db()
        if db.remote_online and db.client is not None:
            try:
                db.client.auth.sign_out()
            except Exception:
                pass
        self.current_user = None

    def update_profile(
        self, nickname: str, bio: str, avatar_url: str = ""
    ) -> Dict[str, Any]:
        if not self.current_user:
            return {"ok": False, "error": "尚未登錄"}
        uid = self.current_user["id"]
        db = get_db()
        store = get_remote_store()
        final_avatar = upload_photo(avatar_url) if avatar_url else ""
        payload: Dict[str, Any] = {
            "nickname": nickname.strip() or self.current_user.get("nickname", ""),
            "bio": bio.strip(),
        }
        if final_avatar:
            payload["avatar_url"] = final_avatar

        result = store.update("profiles", payload, id=uid)
        if not result.ok:
            return {"ok": False, "error": result.error, "offline": result.offline}

        if not store.mirror_patch("profiles", payload, id=uid):
            row = dict(result.data or {"id": uid, **payload})
            store.mirror_add("profiles", row)
        self.current_user = copy.deepcopy(
            store.mirror_row("profiles", id=uid) or self.current_user
        )
        db.save_store()
        return {
            "ok": True,
            "user": self.current_user,
            "offline": result.offline,
            "note": OFFLINE_HINT if result.offline else "",
        }

    def get_profile_stats(self, user_id: str) -> Dict[str, int]:
        db = get_db()
        posts = [p for p in db.store.get("posts", []) if p.get("author_id") == user_id]
        trips = [p for p in posts if p.get("type") == "trip"]
        favs = [f for f in db.store.get("favorites", []) if f.get("user_id") == user_id]
        return {
            "post_count": len(posts),
            "favorite_count": len(favs),
            "trip_count": len(trips),
        }
