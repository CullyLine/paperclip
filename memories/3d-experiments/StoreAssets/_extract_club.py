import os, sys, urllib.request, json, base64

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "StoreTungTung-reference.png")
out_dir = os.path.dirname(os.path.abspath(__file__))

with open(ref, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
data_url = "data:image/png;base64," + b64

payload = json.dumps({
    "image_url": data_url,
    "prompt": "Remove the character completely. Keep ONLY the wooden baseball bat by itself, centered on a pure white background. Show the full bat from handle to barrel. Nothing else in the image, just the bat alone on white.",
    "guidance_scale": 4.0,
    "safety_tolerance": "5"
}).encode()

print("Extracting club via FLUX.1 Kontext...")
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/flux-pro/kontext",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(json.dumps(resp, indent=2))

if "images" in resp and resp["images"]:
    img_url = resp["images"][0]["url"]
    out_path = os.path.join(out_dir, "StoreTungTung-club-reference.png")
    print(f"Downloading: {img_url[:80]}...")
    urllib.request.urlretrieve(img_url, out_path)
    size_kb = os.path.getsize(out_path) / 1024
    print(f"Saved: {out_path} ({size_kb:.1f} KB)")
elif "request_id" in resp:
    meta_path = os.path.join(out_dir, "club-extract-submit.json")
    with open(meta_path, "w") as f:
        json.dump(resp, f, indent=2)
    print(f"Queued: {resp['request_id']}")
    print(f"Status: {resp.get('status_url', '')}")
