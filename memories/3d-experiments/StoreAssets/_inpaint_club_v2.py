"""Inpaint the missing handle of the bat using FLUX Fill.

Simpler approach:
1. Crop to the bat, place on larger white canvas with room to extend
2. Mask = the empty white space + a thin overlap with the bat's edge
3. FLUX Fill predicts the handle in the masked region
"""
import os, sys, urllib.request, json, base64
from PIL import Image, ImageFilter
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

bat_w = cmax - cmin
bat_h = rmax - rmin
print(f"Bat bounds: ({cmin},{rmin}) to ({cmax},{rmax}) = {bat_w}x{bat_h}", flush=True)

pad_top = 40
pad_sides = 80
pad_bottom = int(bat_h * 1.2)

canvas_w = bat_w + pad_sides * 2
canvas_h = bat_h + pad_top + pad_bottom
canvas = Image.new("RGBA", (canvas_w, canvas_h), (255, 255, 255, 255))

crop = img.crop((cmin, rmin, cmax, rmax))
canvas.paste(crop, (pad_sides, pad_top), crop)

flat = canvas.convert("RGB")

canvas_arr = np.array(canvas)
bat_alpha = canvas_arr[:, :, 3]
bat_present = bat_alpha > 10

bat_rows_present = np.where(np.any(bat_present, axis=1))[0]
bat_bottom_y = bat_rows_present[-1] if len(bat_rows_present) > 0 else canvas_h // 2

overlap = 25
mask_arr = np.zeros((canvas_h, canvas_w), dtype=np.uint8)

bottom_rows = []
for y in range(max(0, bat_bottom_y - 30), bat_bottom_y + 1):
    cols_at = np.where(bat_present[y, :])[0]
    if len(cols_at) > 0:
        bottom_rows.append((y, cols_at[0], cols_at[-1]))

if len(bottom_rows) >= 2:
    y1, l1, r1 = bottom_rows[0]
    y2, l2, r2 = bottom_rows[-1]
    dy = y2 - y1 if y2 != y1 else 1
    dl_per_row = (l2 - l1) / dy
    dr_per_row = (r2 - r1) / dy
    center1 = (l1 + r1) / 2
    center2 = (l2 + r2) / 2
    dc_per_row = (center2 - center1) / dy
    width_at_bottom = r2 - l2
else:
    dc_per_row = 0
    dl_per_row = 0
    dr_per_row = 0
    width_at_bottom = 40

for y in range(max(0, bat_bottom_y - overlap), canvas_h):
    rows_past = y - bat_bottom_y
    if rows_past < 0:
        cols_at = np.where(bat_present[y, :])[0]
        if len(cols_at) > 0:
            mask_arr[y, cols_at[0]:cols_at[-1]+1] = 255
    else:
        cx = center2 + dc_per_row * rows_past
        w = max(width_at_bottom * 0.8, 20)
        taper = max(0.3, 1.0 - rows_past / (canvas_h - bat_bottom_y))
        w *= taper
        left = max(0, int(cx - w))
        right = min(canvas_w, int(cx + w))
        mask_arr[y, left:right] = 255

mask = Image.fromarray(mask_arr)
mask = mask.filter(ImageFilter.GaussianBlur(radius=5))
mask = mask.point(lambda x: 255 if x > 20 else 0)

flat_path = os.path.join(out_dir, "club-inpaint-input.png")
mask_path = os.path.join(out_dir, "club-inpaint-mask.png")
flat.save(flat_path)
mask.save(mask_path)

white_count = np.sum(np.array(mask) > 128)
print(f"Canvas: {canvas_w}x{canvas_h}", flush=True)
print(f"Mask: {white_count} pixels to inpaint", flush=True)
print(f"Bat bottom Y: {bat_bottom_y}, mask starts at Y: {bat_bottom_y - overlap}", flush=True)

with open(flat_path, "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()
with open(mask_path, "rb") as f:
    mask_b64 = base64.b64encode(f.read()).decode()

payload = json.dumps({
    "image_url": "data:image/png;base64," + img_b64,
    "mask_url": "data:image/png;base64," + mask_b64,
    "prompt": "Continue the wooden baseball bat handle extending naturally, same smooth simple wood, same cartoon 3D style, light brown wood grain, simple handle with no wrapping, white background",
    "output_format": "png",
    "safety_tolerance": "5"
}).encode()

print("Sending to FLUX Fill...", flush=True)
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
