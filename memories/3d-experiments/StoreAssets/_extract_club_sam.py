"""Extract the baseball bat from the reference image using SAM 3 on fal.ai.

Steps:
1. Send image + text prompt "baseball bat" to SAM 3
2. Get the segmentation mask
3. Apply mask to original image, place on white background
"""
import os, sys, urllib.request, json, base64

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

out_dir = os.path.dirname(os.path.abspath(__file__))
ref = os.path.join(out_dir, "StoreTungTung-reference.png")

with open(ref, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
data_url = "data:image/png;base64," + b64

payload = json.dumps({
    "image_url": data_url,
    "prompt": "baseball bat",
    "apply_mask": True,
    "output_format": "png",
    "return_multiple_masks": False,
}).encode()

print("Sending to SAM 3 with prompt 'baseball bat'...")
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/sam-3/image",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

if "request_id" in resp and "images" not in resp:
    rid = resp["request_id"]
    print(f"Queued: {rid}")
    status_url = resp.get("status_url", "")
    response_url = resp.get("response_url", "")
    print(f"Status: {status_url}")

    with open(os.path.join(out_dir, "club-sam-submit.json"), "w") as f:
        json.dump(resp, f, indent=2)

    import time
    for i in range(30):
        time.sleep(5)
        status_req = urllib.request.Request(status_url, headers={"Authorization": "Key " + FAL_KEY})
        status_resp = json.loads(urllib.request.urlopen(status_req).read().decode())
        print(f"  [{i*5}s] {status_resp.get('status', '?')}")
        if status_resp.get("status") == "COMPLETED":
            result_req = urllib.request.Request(response_url, headers={"Authorization": "Key " + FAL_KEY})
            resp = json.loads(urllib.request.urlopen(result_req).read().decode())
            break
    else:
        print("Timed out")
        sys.exit(1)

if "image" in resp and resp["image"]:
    img_url = resp["image"]["url"]
    out_path = os.path.join(out_dir, "StoreTungTung-club-masked.png")
    print(f"Downloading masked image: {img_url[:80]}...")
    urllib.request.urlretrieve(img_url, out_path)
    print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)")

if "masks" in resp:
    for i, mask in enumerate(resp["masks"]):
        mask_url = mask.get("url", "")
        if mask_url:
            mask_path = os.path.join(out_dir, f"StoreTungTung-club-mask-{i}.png")
            urllib.request.urlretrieve(mask_url, mask_path)
            print(f"Mask {i}: {mask_path} ({os.path.getsize(mask_path) // 1024} KB)")

if not resp.get("image") and not resp.get("masks"):
    print("No results. Response:")
    print(json.dumps(resp, indent=2)[:1000])
