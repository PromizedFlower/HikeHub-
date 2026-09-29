"""Step 0 Probe 4: Verify Storage Photo Upload Pipeline."""
import sys
import tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.backend.post_service import upload_photo

if __name__ == "__main__":
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        tmp.write(b"\xff\xd8\xff\xe0JFIF_HIKEHUB_PROBE")
        tmp_path = tmp.name
    url = upload_photo(tmp_path)
    assert url, "Upload URL should not be empty"
    print("[PASS] Step 0 Probe 4: Uploaded photo URL ->", url)
