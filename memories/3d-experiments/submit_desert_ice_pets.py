"""Submit Desert + Ice world pet concepts to fal Hunyuan3D v3; merge into batch-tracker.json.

Requires: FAL_KEY in environment.

Then run (same directory):
  python batch-fetch.py
  python batch-decimate.py
  python batch-rig.py
"""
import base64
import json
import os
import sys
import time
import urllib.request

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY (fal.ai API key) in the environment.")

MODEL = "fal-ai/hunyuan3d-v3/image-to-3d"
HERE = os.path.dirname(os.path.abspath(__file__))
TRACKER = os.path.join(HERE, "batch-tracker.json")

# Tracker keys must match {key}-highpoly.glb / {key}-game-340.glb naming in batch scripts.
PETS = [
    "desert_fennec",
    "desert_meerkat",
    "desert_horned_lizard",
    "desert_camel",
    "ice_arctic_hare",
    "ice_arctic_fox",
    "ice_penguin",
    "ice_frost_sprite",
    "ice_snow_lynx",
]

with open(TRACKER, encoding="utf-8") as f:
    tracker = json.load(f)

for name in PETS:
    if tracker.get(name, {}).get("submitted") and tracker[name].get("request_id"):
        print(f"[SKIP] {name}: already submitted {tracker[name]['request_id']}")
        continue

    img_path = os.path.join(HERE, f"{name}-concept.png")
    if not os.path.isfile(img_path):
        print(f"[MISS] {img_path}")
        continue

    with open(img_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    payload = json.dumps({"input_image_url": "data:image/png;base64," + b64}).encode()
    req = urllib.request.Request(
        "https://queue.fal.run/" + MODEL,
        data=payload,
        method="POST",
        headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
    )
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=120).read().decode())
        rid = resp.get("request_id", "")
        tracker[name] = {
            "request_id": rid,
            "status_url": resp.get("status_url", ""),
            "submitted": True,
        }
        print(f"[OK] {name}: {rid}")
    except Exception as e:
        print(f"[ERR] {name}: {e}")
        tracker[name] = {"error": str(e), "submitted": False}

    with open(TRACKER, "w", encoding="utf-8") as f:
        json.dump(tracker, f, indent=2)

    time.sleep(1)

print(f"\nTracker updated: {TRACKER}")
