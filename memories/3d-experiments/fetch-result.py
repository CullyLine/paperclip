"""Fetch a completed Hunyuan3D job and download the GLB.

Requires env: FAL_KEY

Usage:
  python fetch-result.py <request_id> [MODEL_APP] [OUTPUT_DIR] [OUTPUT_FILENAME.glb]

MODEL_APP: queue app id for result URL, e.g. fal-ai/hunyuan3d-v3 (not .../image-to-3d).
"""
import os
import urllib.request
import json
import sys

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY in the environment.")

REQUEST_ID = sys.argv[1] if len(sys.argv) > 1 else ""
if not REQUEST_ID:
    sys.exit("Usage: python fetch-result.py <request_id> [MODEL_APP] [OUTPUT_DIR] [out.glb]")

MODEL = sys.argv[2] if len(sys.argv) > 2 else "fal-ai/hunyuan3d-v3"
OUTPUT_DIR = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)))
OUT_NAME = sys.argv[4] if len(sys.argv) > 4 else "model-highpoly.glb"

url = f"https://queue.fal.run/{MODEL}/requests/{REQUEST_ID}"
req = urllib.request.Request(url, headers={"Authorization": "Key " + FAL_KEY})

try:
    raw = urllib.request.urlopen(req).read().decode()
    resp = json.loads(raw)
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()[:500]}")
    sys.exit(1)

os.makedirs(OUTPUT_DIR, exist_ok=True)
meta_path = os.path.join(OUTPUT_DIR, "hunyuan3d-result.json")
with open(meta_path, "w", encoding="utf-8") as f:
    json.dump(resp, f, indent=2)

glb_url = None
for key in ("model_glb", "model_mesh", "glb", "mesh"):
    val = resp.get(key)
    if isinstance(val, dict) and val.get("url"):
        glb_url = val["url"]
        print(f"Using GLB URL from field '{key}'")
        break

if not glb_url:
    for key, val in resp.items():
        if isinstance(val, dict) and "url" in val and key != "logs":
            glb_url = val["url"]
            print(f"Using URL from field '{key}'")
            break

if glb_url:
    out_path = os.path.join(OUTPUT_DIR, OUT_NAME)
    print(f"Downloading: {glb_url[:80]}...")
    urllib.request.urlretrieve(glb_url, out_path)
    size_mb = os.path.getsize(out_path) / (1024 * 1024)
    print(f"Saved to {out_path} ({size_mb:.1f} MB)")
else:
    print("No GLB URL found. Response keys:", list(resp.keys()))
    sys.exit(1)
