"""
行山腳 HikeHub · Post & Storage Service (L3 Service Layer)
Author: Member A (Data Architect)

Handles community moments, Q&A questions, hiking trip records, photo upload
to trail-photos bucket (with local media fallback), post editing, and deletion.
"""
import copy
import datetime
import shutil
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional
from app.backend.supabase_client import get_db, get_runtime_root


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


def upload_photo(local_path: str) -> str:
    """
    Upload photo to Supabase Storage bucket 'trail-photos' if online,
    or copy to local runtime media folder and return file:// or https:// URL for QML Image.
    """
    if not local_path:
        return ""
    if local_path.startswith("http://") or local_path.startswith("https://"):
        return local_path

    clean_path = local_path.replace("file:///", "/" if not local_path.startswith("file:///C:") else "")
    clean_path = clean_path.replace("file://", "")
    src = Path(clean_path)
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
                pass
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
    """Create a new moment, question, or trip post and persist to store."""
    db = get_db()
    uploaded_urls = [upload_photo(p) for p in (photos or []) if p]
    meta: Dict[str, Any] = {"tags": tags or ["香港行山"]}
    if trip_meta:
        meta.update(trip_meta)

    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    new_post = {
        "id": str(uuid.uuid4()),
        "author_id": author_id,
        "type": post_type if post_type in ("moment", "question", "trip") else "moment",
        "title": title.strip() or (body.strip()[:24] if body else "山野分享"),
        "body": body.strip(),
        "trail_id": trail_id or "trail-01",
        "meta": meta,
        "like_count": 0,
        "comment_count": 0,
        "favorite_count": 0,
        "created_at": now_iso,
        "photos": uploaded_urls,
    }
    db.store.setdefault("posts", []).insert(0, new_post)
    db.save_store()
    return _enrich_post(new_post, current_user_id=author_id)


def update_post(post_id: str, author_id: str, title: str, body: str) -> Dict[str, Any]:
    """Edit own post title & body."""
    db = get_db()
    for p in db.store.get("posts", []):
        if p["id"] == post_id and p.get("author_id") == author_id:
            p["title"] = title.strip() or p["title"]
            p["body"] = body.strip() or p["body"]
            db.save_store()
            return _enrich_post(p, current_user_id=author_id)
    return {}


def delete_post(post_id: str, author_id: str) -> bool:
    """Delete own post and cascade likes/comments/favorites."""
    db = get_db()
    posts = db.store.get("posts", [])
    before = len(posts)
    db.store["posts"] = [
        p for p in posts if not (p["id"] == post_id and p.get("author_id") == author_id)
    ]
    if len(db.store["posts"]) < before:
        db.store["comments"] = [c for c in db.store.get("comments", []) if c.get("post_id") != post_id]
        db.store["likes"] = [lk for lk in db.store.get("likes", []) if lk.get("post_id") != post_id]
        db.store["favorites"] = [
            fv for fv in db.store.get("favorites", [])
            if not (fv.get("target_type") == "post" and fv.get("target_id") == post_id)
        ]
        db.save_store()
        return True
    return False
