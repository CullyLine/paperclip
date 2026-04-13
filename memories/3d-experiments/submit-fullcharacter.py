#!/usr/bin/env python3
"""
Submit reference to Hunyuan3D v3 for full-character (non-chibi) assets.
Saves outputs to StoreAssets/ when using full-character style.
"""
import os
import sys
import urllib.request
import json
import base64
from pathlib import Path

# Force full-character style - ignore all chibi pet rules
STYLE = "full-character"
OUTPUT_DIR = Path(r"F:\CODE STUFF\Paperclip\memories\3d-experiments\StoreAssets")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    print("ERROR: Set FAL_KEY environment variable")
    sys.exit(1)

REFERENCE_IMAGE = Path(r"F:\CODE STUFF\Paperclip\memories\3d-experiments\StoreAssets\StoreTungTung-reference.png")
NAME = "StoreTungTung"

print(f"Generating full-character asset: {NAME}")
print(f"Using reference: {REFERENCE_IMAGE.name}")
print("Style: full-character (ignoring all chibi pet rules)")
print("Target: low-poly ~500 faces, highpoly sent to Anymate\n")

with open(REFERENCE_IMAGE, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
data_url = "data:image/png;base64," + b64

payload = json.dumps({
    "input_image_url": data_url,
    "prompt": "highly detailed realistic wooden character exactly matching the reference image, clean smooth edges, accurate anatomy and proportions, full body, T-pose with baseball bat, transparent background removed, professional low-poly game asset style, smooth shading, clean topology"
}).encode()

req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/hunyuan3d-v3/image-to-3d",
    data=payload,
    method="POST",
    headers={
        "Authorization": "Key " + FAL_KEY,
        "Content-Type": "application/json",
    },
)

print("Submitting to Hunyuan3D v3...")
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(json.dumps(resp, indent=2))

meta_path = OUTPUT_DIR / f"{NAME}-hunyuan-submit.json"
with open(meta_path, "w", encoding="utf-8") as f:
    json.dump(resp, f, indent=2)

print(f"\nRequest saved to {meta_path}")
print(f"Status URL: {resp.get('status_url')}")
print("\nNext: Run fetch-result.py with the request_id to download highpoly GLB to StoreAssets/")
print(f"Example: python memories/3d-experiments/fetch-result.py {resp.get('request_id', '')} fal-ai/hunyuan3d-v3 \"{OUTPUT_DIR}\" {NAME}-highpoly.glb")
