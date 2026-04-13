"""Transfer pose from a reference onto an existing character using fal.ai Leffa.

Usage:
  python pose-transfer.py <person_image> <pose_image> <output_path>

person_image: The original character (keeps their appearance)
pose_image: The pose to apply (only the pose is used, not the appearance)
output_path: Where to save the result

Requires: FAL_KEY environment variable
"""
import os, sys, urllib.request, json, base64, time

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY environment variable")

person_image = sys.argv[1]
pose_image = sys.argv[2]
output_path = sys.argv[3]

def to_data_url(path):
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    ext = os.path.splitext(path)[1].lower()
    mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}.get(ext.strip("."), "image/png")
    return f"data:{mime};base64,{b64}"

print(f"Person (character): {os.path.basename(person_image)}")
print(f"Pose reference:     {os.path.basename(pose_image)}")
print(f"Output:             {output_path}")

person_url = to_data_url(person_image)
pose_url = to_data_url(pose_image)

payload = json.dumps({
    "person_image_url": person_url,
    "pose_image_url": pose_url,
    "num_inference_steps": 50,
    "guidance_scale": 2.5,
    "output_format": "png",
    "enable_safety_checker": False,
}).encode()

print("\nSubmitting to Leffa Pose Transfer...")
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/leffa/pose-transfer",
    data=payload,
    method="POST",
    headers={
        "Authorization": "Key " + FAL_KEY,
        "Content-Type": "application/json",
    },
)
resp = json.loads(urllib.request.urlopen(req).read().decode())
request_id = resp.get("request_id", "")
status_url = resp.get("status_url", "")
print(f"Request ID: {request_id}")

print("Polling for completion...")
for i in range(120):
    time.sleep(3)
    req = urllib.request.Request(status_url, headers={"Authorization": "Key " + FAL_KEY})
    status_resp = json.loads(urllib.request.urlopen(req).read().decode())
    status = status_resp.get("status", "UNKNOWN")
    print(f"  [{i*3}s] {status}")
    if status == "COMPLETED":
        break
    if status in ("FAILED", "CANCELLED"):
        print(f"FAILED: {status_resp}")
        sys.exit(1)

response_url = resp.get("response_url", f"https://queue.fal.run/fal-ai/leffa/pose-transfer/requests/{request_id}")
req = urllib.request.Request(response_url, headers={"Authorization": "Key " + FAL_KEY})
result = json.loads(urllib.request.urlopen(req).read().decode())

image_url = result.get("image", {}).get("url", "")
if not image_url:
    print(f"No image URL in result: {list(result.keys())}")
    sys.exit(1)

print(f"Downloading result...")
urllib.request.urlretrieve(image_url, output_path)
size_kb = os.path.getsize(output_path) // 1024
print(f"Saved: {output_path} ({size_kb} KB)")
print("Done!")
