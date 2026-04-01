"""Submit Cappuccino V2 and Tung Tung V2 concept art to Hunyuan3D v3."""
import os
import urllib.request
import json
import base64
import sys

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY in the environment (fal.ai API key).")

DIR = os.path.dirname(os.path.abspath(__file__))
MODEL = "fal-ai/hunyuan3d-v3/image-to-3d"

pets = [
    ("cappuccino", os.path.join(DIR, "pet-cappuccino-v2-concept.png")),
    ("tungtung", os.path.join(DIR, "pet-tungtung-v2-concept.png")),
]

results = {}

for name, img_path in pets:
    if not os.path.exists(img_path):
        print(f"[SKIP] {name}: {img_path} not found")
        continue

    print(f"[SUBMIT] {name}...")
    with open(img_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    data_url = "data:image/png;base64," + b64

    payload = json.dumps({"input_image_url": data_url}).encode()
    req = urllib.request.Request(
        "https://queue.fal.run/" + MODEL,
        data=payload,
        method="POST",
        headers={
            "Authorization": "Key " + FAL_KEY,
            "Content-Type": "application/json",
        },
    )

    try:
        resp = json.loads(urllib.request.urlopen(req).read().decode())
        rid = resp.get("request_id", "???")
        print(f"  request_id: {rid}")
        print(f"  status_url: {resp.get('status_url', 'N/A')}")
        results[name] = resp
    except Exception as e:
        print(f"  ERROR: {e}")
        results[name] = {"error": str(e)}

# Save tracker
tracker_path = os.path.join(DIR, "v2-submit-tracker.json")
with open(tracker_path, "w") as f:
    json.dump(results, f, indent=2)
print(f"\nTracker saved: {tracker_path}")

# Print fetch commands
print("\nFetch commands (run after ~3 min):")
for name, resp in results.items():
    rid = resp.get("request_id", "")
    if rid:
        out_name = f"{name}-highpoly.glb"
        print(f'  python "{os.path.join(DIR, "fetch-result.py")}" {rid} fal-ai/hunyuan3d-v3 "{DIR}" {out_name}')
