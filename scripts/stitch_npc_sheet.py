from PIL import Image
from pathlib import Path

assets = Path(r"C:\Users\lineb\.cursor\projects\f-CODE-STUFF-Paperclip\assets")
rows = [
    assets / "osrs-npcs-row1.png",
    assets / "osrs-npcs-row2.png",
    assets / "osrs-npcs-row3.png",
    assets / "osrs-npcs-row4.png",
    assets / "osrs-npcs-row5.png",
]

images = [Image.open(p) for p in rows]

max_w = max(img.width for img in images)
total_h = sum(img.height for img in images)

sheet = Image.new("RGB", (max_w, total_h), (255, 255, 255))
y = 0
for img in images:
    x_offset = (max_w - img.width) // 2
    sheet.paste(img, (x_offset, y))
    y += img.height

out = Path(r"f:\CODE STUFF\Paperclip\assets") / "osrs-npcs-concept-sheet-v2.png"
sheet.save(out, quality=95)
print(f"Saved: {out}")
print(f"Size: {sheet.width}x{sheet.height}")
