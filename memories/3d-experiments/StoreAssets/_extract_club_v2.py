import os, urllib.request, json, base64

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    exit("Set FAL_KEY")

ref = os.path.join(os.path.dirname(os.path.abspath(__file__)), "StoreTungTung-reference.png")
out_dir = os.path.dirname(os.path.abspath(__file__))

with open(ref, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()

payload = json.dumps({
    "image_url": "data:image/png;base64," + b64,
    "prompt": "Replace the entire character with a plain white background. Only the wooden baseball bat should remain, floating by itself centered on pure white. Remove the character body, face, arms, legs - everything except the baseball bat. Just the bat alone on white.",
    "guidance_scale": 5.0,
    "safety_tolerance": "5"
}).encode()

print("Extracting club v2...")
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/flux-pro/kontext",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

rid = resp.get("request_id", "")
status = resp.get("status_url", "")
print(f"Request ID: {rid}")
print(f"Status URL: {status}")

with open(os.path.join(out_dir, "club-extract-v2.json"), "w") as f:
    json.dump(resp, f, indent=2)
