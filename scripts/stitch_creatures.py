from PIL import Image
from pathlib import Path

src = Path(r"C:\Users\lineb\.cursor\projects\f-CODE-STUFF-Paperclip\assets")
rows = [src / f"osrs-creatures-row{i}.png" for i in range(1, 6)]
images = [Image.open(p) for p in rows]

max_w = max(img.width for img in images)
total_h = sum(img.height for img in images)

sheet = Image.new("RGB", (max_w, total_h), (255, 255, 255))
y = 0
for img in images:
    x_offset = (max_w - img.width) // 2
    sheet.paste(img, (x_offset, y))
    y += img.height

out = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-creatures-concept-sheet.png")
sheet.save(out, quality=95)
print(f"Saved: {out} ({sheet.width}x{sheet.height})")
