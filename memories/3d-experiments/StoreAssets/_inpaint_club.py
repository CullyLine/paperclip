"""Inpaint the missing handle of the bat using FLUX Fill.

Steps:
1. Load the SAM-extracted bat (has transparency where the character was)
2. Create a mask: white where pixels are missing/transparent, black where bat exists
3. Expand the canvas slightly so the bat isn't cropped at edges
4. Send image + mask to FLUX Fill to inpaint just the missing handle
"""
import os, sys, urllib.request, json, base64
from PIL import Image, ImageFilter, ImageDraw
import numpy as np

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

out_dir = os.path.dirname(os.path.abspath(__file__))
masked_bat = os.path.join(out_dir, "StoreTungTung-club-masked.png")

print("Loading extracted bat...", flush=True)
img = Image.open(masked_bat).convert("RGBA")
arr = np.array(img)

alpha = arr[:, :, 3]
rows = np.any(alpha > 10, axis=1)
cols = np.any(alpha > 10, axis=0)
rmin, rmax = np.where(rows)[0][[0, -1]]
cmin, cmax = np.where(cols)[0][[0, -1]]

padding = 60
crop = img.crop((max(0, cmin - padding), max(0, rmin - padding),
                  min(img.width, cmax + padding), min(img.height, rmax + padding)))

canvas_size = max(crop.width, crop.height) + 80
canvas = Image.new("RGBA", (canvas_size, canvas_size), (255, 255, 255, 255))
paste_x = (canvas_size - crop.width) // 2
paste_y = (canvas_size - crop.height) // 2
canvas.paste(crop, (paste_x, paste_y), crop)

flat = canvas.convert("RGB")
flat_path = os.path.join(out_dir, "club-inpaint-input.png")
flat.save(flat_path)
print(f"Input image: {canvas_size}x{canvas_size}", flush=True)

canvas_arr = np.array(canvas)
bat_alpha = canvas_arr[:, :, 3]

mask = Image.new("L", (canvas_size, canvas_size), 0)
mask_arr = np.array(mask)

bat_pixels = bat_alpha > 10
if np.any(bat_pixels):
    bat_rows = np.where(np.any(bat_pixels, axis=1))[0]
    bat_cols = np.where(np.any(bat_pixels, axis=0))[0]
    
    bat_top = bat_rows[0]
    bat_bottom = bat_rows[-1]
    bat_left = bat_cols[0]
    bat_right = bat_cols[-1]
    
    extend = 40
    
    for y in range(bat_top, min(bat_bottom + extend, canvas_size)):
        for x in range(max(0, bat_left - 10), min(bat_right + 10, canvas_size)):
            if bat_alpha[y, x] < 10:
                nearby_has_bat = False
                for dy in range(-15, 16):
                    for dx in range(-15, 16):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < canvas_size and 0 <= nx < canvas_size:
                            if bat_alpha[ny, nx] > 10:
                                nearby_has_bat = True
                                break
                    if nearby_has_bat:
                        break
                if nearby_has_bat:
                    mask_arr[y, x] = 255

    mask = Image.fromarray(mask_arr)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=3))
    mask = mask.point(lambda x: 255 if x > 30 else 0)

mask_path = os.path.join(out_dir, "club-inpaint-mask.png")
mask.save(mask_path)

white_pixels = np.sum(np.array(mask) > 128)
print(f"Mask: {white_pixels} pixels to inpaint", flush=True)

with open(flat_path, "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()
with open(mask_path, "rb") as f:
    mask_b64 = base64.b64encode(f.read()).decode()

payload = json.dumps({
    "image_url": "data:image/png;base64," + img_b64,
    "mask_url": "data:image/png;base64," + mask_b64,
    "prompt": "Continue the wooden baseball bat handle, same smooth light brown wood grain, simple cartoon 3D rendered style, extending the bat naturally downward",
    "output_format": "png",
    "safety_tolerance": "5"
}).encode()

print("Sending to FLUX Fill for inpainting...", flush=True)
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/flux-pro/v1/fill",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

if "images" in resp and resp["images"]:
    img_url = resp["images"][0]["url"]
    out_path = os.path.join(out_dir, "StoreTungTung-club-complete.png")
    urllib.request.urlretrieve(img_url, out_path)
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
                img_url = result["images"][0]["url"]
                out_path = os.path.join(out_dir, "StoreTungTung-club-complete.png")
                urllib.request.urlretrieve(img_url, out_path)
                print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)")
            break
else:
    print(json.dumps(resp, indent=2)[:500])
