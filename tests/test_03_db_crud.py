"""Step 0 Probe 3: Verify cloud-backed writes, read-back counters & mirror sync."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.backend.auth_service import AuthService
from app.backend.supabase_client import get_db
from app.backend.remote_store import get_remote_store
from app.backend.trail_service import list_trails, get_trail_detail
from app.backend.post_service import list_posts
from app.backend.social_service import toggle_like

UID = "11111111-1111-4111-8111-111111111101"

if __name__ == "__main__":
    db = get_db()
    store = get_remote_store()
    print("Status Summary:", db.get_status_summary())

    auth = AuthService()
    login = auth.sign_in("ahon@hikehub.hk", "HikeHub2026!")
    assert login["ok"], f"Login failed: {login}"

    trails = list_trails()
    assert len(trails) >= 10, "Expected at least 10 seeded trails"
    detail = get_trail_detail(trails[0]["id"])
    assert len(detail["segments"]) > 0 and len(detail["checkpoints"]) > 0
    assert get_trail_detail("no-such-trail") == {}, "missing trail must not silently fall back"

    posts = list_posts("moment")
    assert len(posts) > 0
    post_id = posts[0]["id"]

    # Every write now returns a structured result; a rejected write must not
    # be reported as success.
    liked = toggle_like(post_id, UID)
    assert liked["ok"], f"Like failed: {liked}"
    undone = toggle_like(post_id, UID)
    assert undone["ok"], f"Unlike failed: {undone}"

    if db.remote_online:
        before = store.fetch_row("posts", "id", post_id)["like_count"]
        liked = toggle_like(post_id, UID)
        mid = store.fetch_row("posts", "id", post_id)["like_count"]
        mirror = store.mirror_row("posts", id=post_id)["like_count"]
        assert mid == before + 1 and mirror == mid, (before, mid, mirror)
        assert toggle_like(post_id, UID)["ok"]
        assert store.fetch_row("posts", "id", post_id)["like_count"] == before
        print("[PASS] Step 0 Probe 3: Trails =", len(trails),
              "| like_count", before, "->", mid, "->", before,
              "| cloud/mirror consistent")
    else:
        print("[WARN] 離線演示模式：略過雲端回讀斷言")
        print("[PASS] Step 0 Probe 3: Trails =", len(trails),
              "| like toggle (mirror only) =", liked)
