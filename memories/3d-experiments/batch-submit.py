"""Batch submit images to fal.ai Hunyuan3D v3 and save all request IDs."""
import os, json, base64, urllib.request, sys, time

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

MODEL = "fal-ai/hunyuan3d-v3/image-to-3d"
ASSETS = r"C:\Users\lineb\.cursor\projects\f-CODE-STUFF-Paperclip\assets"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

PETS = [
    ("tungtung",    "pet-tungtung-concept-v3.png"),
    ("bombombini",  "pet-bombombini-concept-v3.png"),
    ("tralalero",   "pet-tralalero-concept-v4.png"),
    ("bombardiro",  "pet-bombardiro-concept-v4.png"),
    ("cappuccino",  "pet-cappuccino-concept-v3.png"),
]

results = {}
tracker_path = os.path.join(OUT_DIR, "batch-tracker.json")

if os.path.exists(tracker_path):
    with open(tracker_path) as f:
        results = json.load(f)
    print(f"Resuming: {len(results)} already submitted")

for name, img_file in PETS:
    if name in results:
        print(f"[SKIP] {name} already submitted: {results[name]['request_id']}")
        continue

    img_path = os.path.join(ASSETS, img_file)
    if not os.path.exists(img_path):
        print(f"[MISS] {img_path} not found, skipping")
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
        resp = json.loads(urllib.request.urlopen(req).read().decode())
        rid = resp.get("request_id", "")
        results[name] = {"request_id": rid, "status_url": resp.get("status_url", ""), "submitted": True}
        print(f"[OK]   {name}: {rid}")
    except Exception as e:
        print(f"[ERR]  {name}: {e}")
        results[name] = {"error": str(e), "submitted": False}

    with open(tracker_path, "w") as f:
        json.dump(results, f, indent=2)

    time.sleep(1)

print(f"\nAll submitted. Tracker: {tracker_path}")
for name, info in results.items():
    status = "OK" if info.get("submitted") else "FAILED"
    print(f"  {name}: [{status}] {info.get('request_id', info.get('error', ''))}")
