"""Generate a clean bat/club image matching Tung Tung Sahur's style.

Uses FLUX Pro text-to-image to create a standalone bat reference
for 3D generation. Matching the cartoon 3D rendered aesthetic.
"""
import os, sys, urllib.request, json

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

out_dir = os.path.dirname(os.path.abspath(__file__))

prompt = (
    "A single wooden baseball bat, classic bat shape, wider barrel end "
    "tapering smoothly to thin handle, smooth medium brown wood, "
    "warm tan brown color, 3D cartoon rendered style, very smooth surface, "
    "no visible wood grain, no texture lines, completely smooth matte wood, "
    "centered vertically on pure white background, full length visible, "
    "no text, no hands, no other objects, soft even lighting, "
    "simple game prop, same style as a 3D animated character's weapon, "
    "no knob at the bottom of handle, clean simple silhouette"
)

payload = json.dumps({
    "prompt": prompt,
    "image_size": {"width": 512, "height": 768},
    "output_format": "png",
    "safety_tolerance": "5",
    "num_images": 4,
}).encode()

print("Generating bat references with FLUX Pro...", flush=True)
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/flux-pro/v1.1",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

if "images" in resp and resp["images"]:
    for i, img in enumerate(resp["images"]):
        out_path = os.path.join(out_dir, f"StoreTungTung-club-gen-{i+1}.png")
        urllib.request.urlretrieve(img["url"], out_path)
        print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)")
elif "request_id" in resp:
    rid = resp["request_id"]
    status_url = resp.get("status_url", "")
    response_url = resp.get("response_url", "")
    print(f"Queued: {rid}")

    import time
    for i in range(30):
        time.sleep(5)
        sreq = urllib.request.Request(status_url, headers={"Authorization": "Key " + FAL_KEY})
        sresp = json.loads(urllib.request.urlopen(sreq).read().decode())
        print(f"  [{i*5}s] {sresp.get('status', '?')}")
        if sresp.get("status") == "COMPLETED":
            rreq = urllib.request.Request(response_url, headers={"Authorization": "Key " + FAL_KEY})
            result = json.loads(urllib.request.urlopen(rreq).read().decode())
            if "images" in result and result["images"]:
                for j, img in enumerate(result["images"]):
                    out_path = os.path.join(out_dir, f"StoreTungTung-club-gen-{j+1}.png")
                    urllib.request.urlretrieve(img["url"], out_path)
                    print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)")
            break
