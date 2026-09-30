"""Step 0 Probe 6: Verify Dual-Source LocationProvider (System + Simulated Fallback)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.backend.location_service import DualLocationCoordinator
from app.backend.trail_service import get_trail_detail

if __name__ == "__main__":
    trail = get_trail_detail("trail-01")
    coord = DualLocationCoordinator()
    state0 = coord.start_session(trail["path"])
    state1 = coord.tick()
    coord.stop_session()
    assert "lat" in state1 and "lng" in state1 and len(state1["walked_path"]) >= 1
    print("[PASS] Step 0 Probe 6: Dual location source state =", state1["mode_label"], state1["lat"], state1["lng"])
