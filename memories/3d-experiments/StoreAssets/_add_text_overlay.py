"""Add Unity Asset Store style text overlay to the thumbnail."""
from PIL import Image, ImageDraw, ImageFont
import os

out_dir = os.path.dirname(os.path.abspath(__file__))
thumb_path = os.path.join(out_dir, "StoreTungTung-thumbnail.png")

img = Image.open(thumb_path).convert("RGBA")
overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

text = "Tung Tung Sahur"
font_size = 72
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", font_size)
except:
    font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]

x = (img.width - tw) // 2
y = img.height - th - 55

pad_x = 28
pad_y = 16
draw.rounded_rectangle(
    [x - pad_x, y - pad_y, x + tw + pad_x, y + th + pad_y],
    radius=14,
    fill=(0, 0, 0, 180),
)

draw.text((x + 2, y + 2), text, font=font, fill=(0, 0, 0, 130))
draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

result = Image.alpha_composite(img, overlay)
result.convert("RGB").save(thumb_path)

print(f"Done: {thumb_path} ({os.path.getsize(thumb_path) // 1024} KB)")
