"""Step 0 Probe 3: Verify 9-Table Schema Read/Write & Trail/Social Services."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.backend.trail_service import list_trails, get_trail_detail
from app.backend.post_service import list_posts
from app.backend.social_service import toggle_like

if __name__ == "__main__":
    trails = list_trails()
    assert len(trails) >= 10, "Expected at least 10 seeded trails"
    detail = get_trail_detail(trails[0]["id"])
    assert len(detail["segments"]) > 0 and len(detail["checkpoints"]) > 0
    posts = list_posts("moment")
    assert len(posts) > 0
    like_res = toggle_like(posts[0]["id"], "11111111-1111-4111-8111-111111111101")
    print("[PASS] Step 0 Probe 3: Trails count =", len(trails), "| Like toggle =", like_res)
