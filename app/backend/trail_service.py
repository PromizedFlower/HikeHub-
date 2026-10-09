"""
行山腳 HikeHub · Trail Service (L3 Service Layer)
Author: Member A (Data Architect)

Provides route listing, region/difficulty/duration filtering, keyword search,
route detail with segments & checkpoints, and homepage featured/nearby routes.
"""
import copy
from typing import Any, Dict, List, Optional
from app.backend.supabase_client import get_db


def list_trails(
    region: str = "全部",
    difficulty: int = 0,
    duration_bucket: str = "全部",
    keyword: str = "",
    current_user_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Return trails filtered by region, difficulty (1..5 or 0=all),
    duration_bucket ('全部' | '3小時內' | '3-4小時' | '4小時以上'), and keyword.
    """
    db = get_db()
    trails = copy.deepcopy(db.store.get("trails", []))
    favorites = db.store.get("favorites", [])
    fav_trail_ids = {
        f["target_id"]
        for f in favorites
        if f.get("target_type") == "trail" and f.get("user_id") == current_user_id
    }

    results: List[Dict[str, Any]] = []
    kw = keyword.strip().lower()

    for t in trails:
        if region and region != "全部" and t.get("region") != region:
            continue
        if difficulty and int(t.get("difficulty", 0)) != int(difficulty):
            continue
        dur = int(t.get("duration_min", 0))
        if duration_bucket == "3小時內" and dur > 180:
            continue
        elif duration_bucket == "3-4小時" and (dur <= 180 or dur > 240):
            continue
        elif duration_bucket == "4小時以上" and dur <= 240:
            continue
        if kw:
            haystack = f"{t.get('name', '')} {t.get('region', '')} {t.get('description', '')}".lower()
            if kw not in haystack:
                continue

        t["is_favorited"] = t["id"] in fav_trail_ids
        results.append(t)

    return results


def get_trail_detail(trail_id: str, current_user_id: Optional[str] = None) -> Dict[str, Any]:
    """Return full trail detail including ordered segments, checkpoints, and related posts."""
    db = get_db()
    trails = db.store.get("trails", [])
    trail = next((copy.deepcopy(t) for t in trails if t["id"] == trail_id), None)
    if not trail:
        if trails:
            trail = copy.deepcopy(trails[0])
            trail_id = trail["id"]
        else:
            return {}

    segments = [
        copy.deepcopy(s)
        for s in db.store.get("trail_segments", [])
        if s.get("trail_id") == trail_id
    ]
    segments.sort(key=lambda x: x.get("seq", 0))

    checkpoints = [
        copy.deepcopy(c)
        for c in db.store.get("checkpoints", [])
        if c.get("trail_id") == trail_id
    ]
    checkpoints.sort(key=lambda x: x.get("seq", 0))

    favorites = db.store.get("favorites", [])
    trail["is_favorited"] = any(
        f.get("user_id") == current_user_id
        and f.get("target_type") == "trail"
        and f.get("target_id") == trail_id
        for f in favorites
    )
    trail["segments"] = segments
    trail["checkpoints"] = checkpoints
    return trail


def get_home_feed(current_user_id: Optional[str] = None) -> Dict[str, Any]:
    """Return Home Tab fixed sections: 2 featured trails, 5 nearby trails, and 3 top hot posts."""
    from app.backend.post_service import list_posts

    all_trails = list_trails(current_user_id=current_user_id)
    featured = sorted(all_trails, key=lambda t: t.get("favorite_count", 0), reverse=True)[:2]
    nearby = all_trails[:5]

    all_posts = list_posts(post_type="all", current_user_id=current_user_id)
    hot_posts = sorted(all_posts, key=lambda p: p.get("like_count", 0), reverse=True)[:3]

    return {
        "featured_trails": featured,
        "nearby_trails": nearby,
        "hot_posts": hot_posts,
    }
