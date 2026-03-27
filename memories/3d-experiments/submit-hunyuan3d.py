"""Submit an image to fal.ai Hunyuan3D (textured mesh).

Default: fal-ai/hunyuan3d-v3/image-to-3d — full PBR/textured GLB (~2 min, higher cost).
Do NOT use fal-ai/hunyuan3d/v2 for shipping assets — it is geometry-only / lightly textured.

Requires env: FAL_KEY

Usage:
  python submit-hunyuan3d.py [MODEL] [IMAGE_PATH] [OUTPUT_DIR]
"""
import os
import urllib.request
import json
import base64
import sys

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY in the environment (fal.ai API key).")

# v3 image-to-3d = textured production mesh. v2 = fast prototype, not for release art.
_MODEL_DEFAULT = "fal-ai/hunyuan3d-v3/image-to-3d"
_HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = sys.argv[1] if len(sys.argv) > 1 else _MODEL_DEFAULT
IMAGE_PATH = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_HERE, "reference-for-3d.png")
OUTPUT_DIR = sys.argv[3] if len(sys.argv) > 3 else _HERE

with open(IMAGE_PATH, "rb") as f:
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
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(json.dumps(resp, indent=2))

out_file = os.path.join(OUTPUT_DIR, "hunyuan3d-submit.json")
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(resp, f, indent=2)
print(f"\nSaved to {out_file}")
print(f"Status URL: {resp.get('status_url', 'N/A')}")
print(f"Poll: python fetch-result.py {resp.get('request_id', '')} fal-ai/hunyuan3d-v3")
