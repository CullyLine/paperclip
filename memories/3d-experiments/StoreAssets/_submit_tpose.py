import os, sys, urllib.request, json, base64

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "StoreTungTung-tpose-kontext.png")
out_dir = os.path.dirname(os.path.abspath(__file__))

with open(ref, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
data_url = "data:image/png;base64," + b64

payload = json.dumps({"input_image_url": data_url}).encode()
print("Submitting T-pose to Hunyuan3D v3...")
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/hunyuan3d-v3/image-to-3d",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
print(json.dumps(resp, indent=2))

meta = os.path.join(out_dir, "StoreTungTung-tpose-submit.json")
with open(meta, "w") as f:
    json.dump(resp, f, indent=2)

rid = resp.get("request_id", "")
print(f"\nRequest ID: {rid}")
print(f"Status URL: {resp.get('status_url', '')}")
print(f"\nFetch command:")
print(f'python memories/3d-experiments/fetch-result.py {rid} fal-ai/hunyuan3d-v3 "{out_dir}" StoreTungTung-tpose-highpoly.glb')
