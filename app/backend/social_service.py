"""
行山腳 HikeHub · Social Interaction Service (L3 Service Layer)
Author: Member A (Data Architect)

Implements single like/unlike, trail & post favorites, 1-level comments + 1-layer reply,
and Q&A answer acceptance (one-time irreversible per question).
"""
import datetime
import uuid
from typing import Any, Dict, List
from app.backend.supabase_client import get_db
from app.backend.post_service import list_posts
from app.backend.trail_service import list_trails


def toggle_like(post_id: str, user_id: str) -> Dict[str, Any]:
    """Toggle like on a post and update redundant like_count immediately."""
    db = get_db()
    likes = db.store.setdefault("likes", [])
    existing = next(
        (lk for lk in likes if lk.get("post_id") == post_id and lk.get("user_id") == user_id),
        None,
    )
    is_liked = False
    if existing:
        likes.remove(existing)
        delta = -1
    else:
        likes.append({"post_id": post_id, "user_id": user_id})
        delta = 1
        is_liked = True

    new_count = 0
    for p in db.store.get("posts", []):
        if p["id"] == post_id:
            p["like_count"] = max(0, int(p.get("like_count", 0)) + delta)
            new_count = p["like_count"]
            break

    db.save_store()
    return {"post_id": post_id, "is_liked": is_liked, "like_count": new_count}


def toggle_favorite(target_type: str, target_id: str, user_id: str) -> Dict[str, Any]:
    """Toggle favorite on a trail or post (`target_type` in {'trail', 'post'})."""
    db = get_db()
    favorites = db.store.setdefault("favorites", [])
    existing = next(
        (
            fv for fv in favorites
            if fv.get("user_id") == user_id
            and fv.get("target_type") == target_type
            and fv.get("target_id") == target_id
        ),
        None,
    )
    is_fav = False
    if existing:
        favorites.remove(existing)
        delta = -1
    else:
        favorites.append({"user_id": user_id, "target_type": target_type, "target_id": target_id})
        delta = 1
        is_fav = True

    new_count = 0
    collection = "trails" if target_type == "trail" else "posts"
    for item in db.store.get(collection, []):
        if item["id"] == target_id:
            item["favorite_count"] = max(0, int(item.get("favorite_count", 0)) + delta)
            new_count = item["favorite_count"]
            break

    db.save_store()
    return {
        "target_type": target_type,
        "target_id": target_id,
        "is_favorited": is_fav,
        "favorite_count": new_count,
    }


def add_comment(
    post_id: str,
    author_id: str,
    body: str,
    parent_id: str = "",
) -> Dict[str, Any]:
    """Add a 1st-level comment or 1-layer reply (`parent_id`) to a post."""
    db = get_db()
    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    new_comment = {
        "id": str(uuid.uuid4()),
        "post_id": post_id,
        "author_id": author_id,
        "parent_id": parent_id if parent_id else None,
        "body": body.strip(),
        "is_accepted": False,
        "created_at": now_iso,
    }
    db.store.setdefault("comments", []).append(new_comment)
    for p in db.store.get("posts", []):
        if p["id"] == post_id:
            p["comment_count"] = int(p.get("comment_count", 0)) + 1
            break
    db.save_store()
    return new_comment


def accept_comment(post_id: str, comment_id: str, current_user_id: str) -> bool:
    """
    Mark a comment as the accepted answer for a 'question' post.
    Only the post author can accept, and once accepted it cannot be undone.
    """
    db = get_db()
    post = next((p for p in db.store.get("posts", []) if p["id"] == post_id), None)
    if not post or post.get("type") != "question" or post.get("author_id") != current_user_id:
        return False

    comments = [c for c in db.store.get("comments", []) if c.get("post_id") == post_id]
    if any(c.get("is_accepted", False) for c in comments):
        return False

    for c in comments:
        if c["id"] == comment_id:
            c["is_accepted"] = True
            post.setdefault("meta", {})["has_accepted"] = True
            db.save_store()
            return True
    return False


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
