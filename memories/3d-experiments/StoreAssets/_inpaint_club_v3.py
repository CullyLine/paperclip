"""Inpaint the missing handle of the bat using FLUX Fill.

The SAM-extracted bat has transparency where the character was occluding it.
We detect the bat's extent from the alpha channel BEFORE placing on white canvas,
then create a mask extending from the bat's cut-off edge.
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
print(f"Bat bounds in original: ({cmin},{rmin}) to ({cmax},{rmax}) = {bat_w}x{bat_h}", flush=True)

crop = img.crop((cmin, rmin, cmax + 1, rmax + 1))
crop_alpha = np.array(crop)[:, :, 3]
bat_mask_original = crop_alpha > 10

pad_top = 30
pad_sides = 60
pad_bottom = int(bat_h * 1.0)

canvas_w = bat_w + pad_sides * 2 + 1
canvas_h = bat_h + pad_top + pad_bottom + 1

bat_x_offset = pad_sides
bat_y_offset = pad_top

canvas_rgba = Image.new("RGBA", (canvas_w, canvas_h), (255, 255, 255, 255))
canvas_rgba.paste(crop, (bat_x_offset, bat_y_offset), crop)
flat = canvas_rgba.convert("RGB")

bat_in_canvas = np.zeros((canvas_h, canvas_w), dtype=bool)
for y in range(crop_alpha.shape[0]):
    for x in range(crop_alpha.shape[1]):
        if crop_alpha[y, x] > 10:
            bat_in_canvas[y + bat_y_offset, x + bat_x_offset] = True

bat_rows_idx = np.where(np.any(bat_in_canvas, axis=1))[0]
bat_top_y = bat_rows_idx[0]
bat_bottom_y = bat_rows_idx[-1]
print(f"Bat in canvas: Y {bat_top_y} to {bat_bottom_y}, canvas {canvas_w}x{canvas_h}", flush=True)

bottom_sample = []
for y in range(max(bat_top_y, bat_bottom_y - 40), bat_bottom_y + 1):
    cols_at = np.where(bat_in_canvas[y, :])[0]
    if len(cols_at) > 0:
        bottom_sample.append((y, cols_at[0], cols_at[-1]))

if len(bottom_sample) >= 2:
    y1, l1, r1 = bottom_sample[0]
    y2, l2, r2 = bottom_sample[-1]
    dy = max(y2 - y1, 1)
    center2 = (l2 + r2) / 2.0
    dc_per_row = ((l2 + r2) / 2.0 - (l1 + r1) / 2.0) / dy
    width_bottom = r2 - l2
    print(f"Direction: center drifts {dc_per_row:.2f} px/row, width at bottom: {width_bottom}", flush=True)
else:
    center2 = canvas_w / 2
    dc_per_row = 0
    width_bottom = 30

overlap = 20
mask_arr = np.zeros((canvas_h, canvas_w), dtype=np.uint8)

for y in range(max(0, bat_bottom_y - overlap), canvas_h):
    dist = y - bat_bottom_y
    if dist < 0:
        cols_at = np.where(bat_in_canvas[y, :])[0]
        if len(cols_at) > 0:
            mask_arr[y, cols_at[0]:cols_at[-1]+1] = 255
    else:
        cx = center2 + dc_per_row * dist
        w = max(width_bottom * 0.7, 15)
        taper = max(0.2, 1.0 - dist / max(canvas_h - bat_bottom_y, 1) * 0.7)
        w *= taper
        left = max(0, int(cx - w))
        right = min(canvas_w, int(cx + w))
        mask_arr[y, left:right] = 255

mask = Image.fromarray(mask_arr)
mask = mask.filter(ImageFilter.GaussianBlur(radius=4))
mask = mask.point(lambda x: 255 if x > 20 else 0)

flat_path = os.path.join(out_dir, "club-inpaint-input.png")
mask_path = os.path.join(out_dir, "club-inpaint-mask.png")
flat.save(flat_path)
mask.save(mask_path)

white_count = np.sum(np.array(mask) > 128)
print(f"Mask: {white_count} pixels to inpaint", flush=True)

with open(flat_path, "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()
with open(mask_path, "rb") as f:
    mask_b64 = base64.b64encode(f.read()).decode()

payload = json.dumps({
    "image_url": "data:image/png;base64," + img_b64,
    "mask_url": "data:image/png;base64," + mask_b64,
    "prompt": "Continue the wooden baseball bat handle extending naturally downward, same smooth simple wood, same cartoon 3D style, light brown wood grain, simple cylindrical handle tapering to the grip end, white background",
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
