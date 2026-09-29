"""Step 0 Probe 2: Verify Supabase Auth & .env Configuration."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.backend.supabase_client import get_db
from app.backend.auth_service import AuthService

if __name__ == "__main__":
    db = get_db()
    print("Status Summary:", db.get_status_summary())
    auth = AuthService()
    res = auth.sign_in("ahon@hikehub.hk", "HikeHub2026!")
    assert res["ok"], f"Login failed: {res}"
    print("[PASS] Step 0 Probe 2: Auth login verified for:", res["user"]["nickname"])
