"""
行山腳 HikeHub · Social Interaction Service (L3 Service Layer)
Author: Member A (Data Architect)

Implements single like/unlike, trail & post favorites, 1-level comments + 1-layer reply,
and Q&A answer acceptance (one-time irreversible per question).

Every mutation goes through `RemoteStore`: online writes hit PostgREST first, the
trigger-maintained counter is read back, and only then is the local mirror
updated. Offline writes are mirror-only and explicitly flagged so the bridge
can label them 「離線演示，資料僅存本機」.
"""
import datetime
import uuid
from typing import Any, Dict, List

from app.backend.supabase_client import get_db
from app.backend.remote_store import get_remote_store, OFFLINE_HINT
from app.backend.post_service import list_posts
from app.backend.trail_service import list_trails


def _note(offline: bool) -> str:
    return OFFLINE_HINT if offline else ""


def toggle_like(post_id: str, user_id: str) -> Dict[str, Any]:
    """Toggle like; `like_count` always comes from a cloud read-back."""
    db = get_db()
    store = get_remote_store()
    existing = store.mirror_row("likes", post_id=post_id, user_id=user_id)

    if existing:
        result = store.delete("likes", post_id=post_id, user_id=user_id)
        is_liked = False
        if result.ok:
            store.mirror_remove("likes", post_id=post_id, user_id=user_id)
    else:
        result = store.insert("likes", {"post_id": post_id, "user_id": user_id})
        is_liked = True
        if result.ok:
            store.mirror_add("likes", {"post_id": post_id, "user_id": user_id})

    if not result.ok:
        return {
            "ok": False,
            "post_id": post_id,
            "error": result.error,
            "offline": result.offline,
        }

    new_count = store.refresh_counter("posts", post_id, "like_count")
    store.mirror_patch("posts", {"like_count": new_count}, id=post_id)
    db.save_store()
    return {
        "ok": True,
        "post_id": post_id,
        "is_liked": is_liked,
        "like_count": new_count,
        "offline": result.offline,
        "note": _note(result.offline),
    }


def toggle_favorite(target_type: str, target_id: str, user_id: str) -> Dict[str, Any]:
    """Toggle a trail/post favorite and read the authoritative counter back."""
    if target_type not in ("trail", "post"):
        return {"ok": False, "error": "不支援的收藏類型"}
    db = get_db()
    store = get_remote_store()
    filters = {
        "user_id": user_id,
        "target_type": target_type,
        "target_id": target_id,
    }
    existing = store.mirror_row("favorites", **filters)

    if existing:
        result = store.delete("favorites", **filters)
        is_fav = False
        if result.ok:
            store.mirror_remove("favorites", **filters)
    else:
        result = store.insert("favorites", dict(filters))
        is_fav = True
        if result.ok:
            store.mirror_add("favorites", dict(filters))

    if not result.ok:
        return {
            "ok": False,
            "target_type": target_type,
            "target_id": target_id,
            "error": result.error,
            "offline": result.offline,
        }

    table = "trails" if target_type == "trail" else "posts"
    new_count = store.refresh_counter(table, target_id, "favorite_count")
    store.mirror_patch(table, {"favorite_count": new_count}, id=target_id)
    db.save_store()
    return {
        "ok": True,
        "target_type": target_type,
        "target_id": target_id,
        "is_favorited": is_fav,
        "favorite_count": new_count,
        "offline": result.offline,
        "note": _note(result.offline),
    }


def add_comment(
    post_id: str,
    author_id: str,
    body: str,
    parent_id: str = "",
) -> Dict[str, Any]:
    """Add a 1st-level comment or 1-layer reply to a post."""
    clean_body = body.strip()
    if not clean_body:
        return {"ok": False, "error": "評論內容不可空白"}

    db = get_db()
    store = get_remote_store()
    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    new_comment = {
        "id": str(uuid.uuid4()),
        "post_id": post_id,
        "author_id": author_id,
        "parent_id": parent_id if parent_id else None,
        "body": clean_body,
        "is_accepted": False,
        "created_at": now_iso,
    }
    result = store.insert("comments", new_comment)
    if not result.ok:
        return {"ok": False, "error": result.error, "offline": result.offline}

    row = dict(result.data or new_comment)
    store.mirror_add("comments", row)
    new_count = store.refresh_counter("posts", post_id, "comment_count")
    store.mirror_patch("posts", {"comment_count": new_count}, id=post_id)
    db.save_store()
    return {
        "ok": True,
        "comment": row,
        "comment_count": new_count,
        "offline": result.offline,
        "note": _note(result.offline),
    }


def accept_comment(post_id: str, comment_id: str, current_user_id: str) -> Dict[str, Any]:
    """Mark a comment as the accepted answer.

    Only the author of a `question` post may accept, and only once.
    """
    db = get_db()
    store = get_remote_store()
    post = store.mirror_row("posts", id=post_id)
    if not post or post.get("type") != "question" or post.get("author_id") != current_user_id:
        return {"ok": False, "error": "只有提問作者可採納回答"}

    comments = [c for c in db.store.get("comments", []) if c.get("post_id") == post_id]
    if any(c.get("is_accepted", False) for c in comments):
        return {"ok": False, "error": "每題僅限採納一次"}
    if not any(c.get("id") == comment_id for c in comments):
        return {"ok": False, "error": "找不到該回答"}

    result = store.update(
        "comments",
        {"is_accepted": True},
        id=comment_id,
        post_id=post_id,
    )
    if not result.ok:
        return {"ok": False, "error": result.error, "offline": result.offline}

    store.mirror_patch("comments", {"is_accepted": True}, id=comment_id)
    # `has_accepted` is derived from the comments table by `_enrich_post`;
    # no redundant meta flag is written, so mirror and cloud stay identical.
    db.save_store()
    return {
        "ok": True,
        "offline": result.offline,
        "note": _note(result.offline),
    }


def get_user_favorites(user_id: str) -> Dict[str, List[Dict[str, Any]]]:
    """Return user's favorited trails and favorited posts for ProfilePage."""
    db = get_db()
    favorites = [fv for fv in db.store.get("favorites", []) if fv.get("user_id") == user_id]
    fav_trail_ids = {fv["target_id"] for fv in favorites if fv.get("target_type") == "trail"}
    fav_post_ids = {fv["target_id"] for fv in favorites if fv.get("target_type") == "post"}

    all_trails = list_trails(current_user_id=user_id)
    all_posts = list_posts(post_type="all", current_user_id=user_id)

    return {
        "trails": [t for t in all_trails if t["id"] in fav_trail_ids],
        "posts": [p for p in all_posts if p["id"] in fav_post_ids],
    }
