"""
行山腳 HikeHub · Post & Storage Service (L3 Service Layer)
Author: Member A (Data Architect)

Handles community moments, Q&A questions, hiking trip records, photo upload
to the `trail-photos` bucket, post editing and deletion.

All writes go through `RemoteStore`: posts land in `public.posts`, and every
photo is recorded in `public.post_photos` so the same list can be rebuilt by
`sync_mirror()`. `_enrich_post` remains a pure, mirror-only assembler.
"""
import copy
import datetime
import shutil
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname

from app.backend.supabase_client import get_db, get_runtime_root
from app.backend.remote_store import get_remote_store, OFFLINE_HINT


def _note(offline: bool) -> str:
    return OFFLINE_HINT if offline else ""


def _enrich_post(post: Dict[str, Any], current_user_id: Optional[str] = None) -> Dict[str, Any]:
    db = get_db()
    profiles = {p["id"]: p for p in db.store.get("profiles", [])}
    trails = {t["id"]: t for t in db.store.get("trails", [])}
    likes = db.store.get("likes", [])
    favorites = db.store.get("favorites", [])
    comments = db.store.get("comments", [])

    enriched = copy.deepcopy(post)
    author = profiles.get(enriched.get("author_id", ""), {})
    enriched["author_nickname"] = author.get("nickname", "山友")
    enriched["author_avatar"] = author.get("avatar_url", "")

    trail = trails.get(enriched.get("trail_id") or "", {})
    enriched["trail_name"] = trail.get("name", "香港山徑")

    photos = enriched.get("photos", [])
    enriched["cover_photo"] = photos[0] if photos else (trail.get("cover_url") or "")

    post_id = enriched["id"]
    enriched["is_liked"] = any(
        lk.get("post_id") == post_id and lk.get("user_id") == current_user_id
        for lk in likes
    )
    enriched["is_favorited"] = any(
        fv.get("target_type") == "post"
        and fv.get("target_id") == post_id
        and fv.get("user_id") == current_user_id
        for fv in favorites
    )

    post_comments = [c for c in comments if c.get("post_id") == post_id]
    enriched["has_accepted"] = any(c.get("is_accepted", False) for c in post_comments)
    tags = enriched.get("meta", {}).get("tags", [])
    enriched["tags_text"] = " · ".join(f"#{t}" for t in tags) if tags else "#香港行山"
    enriched["created_display"] = enriched.get("created_at", "")[:16].replace("T", " ")
    return enriched


def list_posts(
    post_type: str = "moment",
    author_id: Optional[str] = None,
    trail_id: Optional[str] = None,
    current_user_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    List posts in strict reverse chronological order (created_at DESC).
    post_type: 'moment' (includes 'moment' and 'trip' cards), 'question', or 'all'.
    """
    db = get_db()
    raw_posts = db.store.get("posts", [])
    filtered: List[Dict[str, Any]] = []

    for p in raw_posts:
        # 「僅保存記錄」的行程只對作者本人（我的動態）可見，不進社區流。
        if author_id is None and p.get("meta", {}).get("published") is False:
            continue
        ptype = p.get("type", "moment")
        if post_type == "moment" and ptype not in ("moment", "trip"):
            continue
        elif post_type == "question" and ptype != "question":
            continue
        if author_id and p.get("author_id") != author_id:
            continue
        if trail_id and p.get("trail_id") != trail_id:
            continue
        filtered.append(_enrich_post(p, current_user_id=current_user_id))

    filtered.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return filtered


def get_post_detail(post_id: str, current_user_id: Optional[str] = None) -> Dict[str, Any]:
    """Return full post detail including photos and 1-level + 1-reply comments."""
    db = get_db()
    raw_posts = db.store.get("posts", [])
    post = next((p for p in raw_posts if p["id"] == post_id), None)
    if not post:
        return {}

    enriched = _enrich_post(post, current_user_id=current_user_id)
    profiles = {p["id"]: p for p in db.store.get("profiles", [])}
    all_comments = [
        copy.deepcopy(c) for c in db.store.get("comments", []) if c.get("post_id") == post_id
    ]
    all_comments.sort(key=lambda x: x.get("created_at", ""))

    by_id = {c["id"]: c for c in all_comments}
    formatted_comments: List[Dict[str, Any]] = []
    for c in all_comments:
        author = profiles.get(c.get("author_id", ""), {})
        c["author_nickname"] = author.get("nickname", "山友")
        c["author_avatar"] = author.get("avatar_url", "")
        c["created_display"] = c.get("created_at", "")[:16].replace("T", " ")
        parent_id = c.get("parent_id")
        if parent_id and parent_id in by_id:
            parent_author = profiles.get(by_id[parent_id].get("author_id", ""), {})
            c["reply_to_nickname"] = parent_author.get("nickname", "山友")
        else:
            c["reply_to_nickname"] = ""
        formatted_comments.append(c)

    enriched["comments"] = formatted_comments
    return enriched


def _resolve_local_path(local_path: str) -> Path:
    """Correctly decode a `file:///` URI on Windows (D:/... , UNC, localhost)."""
    if not local_path.startswith("file://"):
        return Path(local_path)
    parsed = urlparse(local_path)
    decoded = url2pathname(unquote(parsed.path))
    if parsed.netloc and parsed.netloc.lower() not in ("", "localhost"):
        decoded = f"//{parsed.netloc}{decoded}"
    return Path(decoded)


def upload_photo(local_path: str, warnings: Optional[List[str]] = None) -> str:
    """
    Upload to Supabase Storage bucket 'trail-photos' when online; otherwise
    copy into a writable local media folder and return a file:// URL.
    Cloud-upload failures are appended to `warnings` so the caller can tell
    the user the photo only exists locally instead of failing silently.
    """
    # QML FileDialog 傳入的是 QUrl；str(QUrl) 會得到 Python 表示式而非路徑。
    if hasattr(local_path, "toString"):
        local_path = str(local_path.toString())
    else:
        local_path = str(local_path or "")
    if not local_path:
        return ""
    if local_path.startswith("http://") or local_path.startswith("https://"):
        return local_path

    src = _resolve_local_path(local_path)
    db = get_db()

    if src.exists():
        ext = src.suffix or ".jpg"
        dest_name = f"upload_{uuid.uuid4().hex[:10]}{ext}"
        if db.remote_online and db.client is not None:
            try:
                with open(src, "rb") as f:
                    db.client.storage.from_(db.bucket_name).upload(dest_name, f.read())
                return db.client.storage.from_(db.bucket_name).get_public_url(dest_name)
            except Exception:
                if warnings is not None:
                    warnings.append("相片上傳雲端失敗，已暫存本機")
        media_dir = get_runtime_root() / "user_uploads"
        media_dir.mkdir(parents=True, exist_ok=True)
        dest_path = media_dir / dest_name
        shutil.copy2(src, dest_path)
        return dest_path.as_uri()

    return local_path


def create_post(
    author_id: str,
    post_type: str,
    title: str,
    body: str,
    trail_id: Optional[str] = None,
    photos: Optional[List[str]] = None,
    tags: Optional[List[str]] = None,
    trip_meta: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Create a moment/question/trip post in the cloud, plus its photo rows."""
    db = get_db()
    store = get_remote_store()
    upload_warnings: List[str] = []
    uploaded_urls = [upload_photo(p, upload_warnings) for p in (photos or []) if p]
    meta: Dict[str, Any] = {"tags": tags or ["香港行山"]}
    if trip_meta:
        meta.update(trip_meta)

    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload = {
        "id": str(uuid.uuid4()),
        "author_id": author_id,
        "type": post_type if post_type in ("moment", "question", "trip") else "moment",
        "title": title.strip() or (body.strip()[:24] if body else "山野分享"),
        "body": body.strip(),
        "trail_id": trail_id or "trail-01",
        "meta": meta,
        "created_at": now_iso,
    }
    result = store.insert("posts", payload)
    if not result.ok:
        return {"ok": False, "error": result.error, "offline": result.offline}

    row = dict(result.data or payload)
    for counter in ("like_count", "comment_count", "favorite_count"):
        row.setdefault(counter, 0)

    warning = "；".join(dict.fromkeys(upload_warnings))
    accepted_urls: List[str] = []
    for url in uploaded_urls:
        photo_payload = {
            "post_id": row["id"],
            "storage_path": url,
            "seq": len(accepted_urls) + 1,
        }
        photo_result = store.insert("post_photos", photo_payload)
        if not photo_result.ok:
            if not warning:
                warning = f"貼文已保存，但部分相片未能寫入雲端：{photo_result.error}"
            continue
        accepted_urls.append(url)
        mirror_photo = dict(photo_payload)
        mirror_photo["id"] = (photo_result.data or {}).get("id") or str(uuid.uuid4())
        store.mirror_add("post_photos", mirror_photo)
    row["photos"] = accepted_urls

    store.mirror_add("posts", row)
    db.save_store()
    return {
        "ok": True,
        "post": _enrich_post(row, current_user_id=author_id),
        "offline": result.offline,
        "note": _note(result.offline),
        "warning": warning,
    }


def update_post(post_id: str, author_id: str, title: str, body: str) -> Dict[str, Any]:
    """Edit own post title & body in the cloud, then patch the mirror."""
    db = get_db()
    store = get_remote_store()
    post = store.mirror_row("posts", id=post_id)
    if not post or post.get("author_id") != author_id:
        return {"ok": False, "error": "只能編輯自己的貼文"}

    payload = {
        "title": title.strip() or post.get("title", ""),
        "body": body.strip() or post.get("body", ""),
    }
    result = store.update("posts", payload, id=post_id, author_id=author_id)
    if not result.ok:
        return {"ok": False, "error": result.error, "offline": result.offline}

    store.mirror_patch("posts", payload, id=post_id)
    db.save_store()
    updated = store.mirror_row("posts", id=post_id) or post
    return {
        "ok": True,
        "post": _enrich_post(updated, current_user_id=author_id),
        "offline": result.offline,
        "note": _note(result.offline),
    }


def delete_post(post_id: str, author_id: str) -> Dict[str, Any]:
    """Delete own post; the cloud cascades likes/comments/photos."""
    db = get_db()
    store = get_remote_store()
    post = store.mirror_row("posts", id=post_id)
    if not post or post.get("author_id") != author_id:
        return {"ok": False, "error": "只能刪除自己的貼文"}

    # favorites.target_id has no FK, so the current user's rows must be removed
    # explicitly (SQL hardening adds a server-side trigger for other users' rows).
    store.delete("favorites", target_type="post", target_id=post_id)

    result = store.delete("posts", id=post_id, author_id=author_id)
    if not result.ok:
        return {"ok": False, "error": result.error, "offline": result.offline}

    store.mirror_remove("posts", id=post_id)
    store.mirror_remove("comments", post_id=post_id)
    store.mirror_remove("likes", post_id=post_id)
    store.mirror_remove("post_photos", post_id=post_id)
    store.mirror_remove("favorites", target_type="post", target_id=post_id)
    db.save_store()
    return {"ok": True, "offline": result.offline, "note": _note(result.offline)}
