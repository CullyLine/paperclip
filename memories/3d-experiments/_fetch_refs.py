"""Download reference images for brainrot characters from the web."""
import urllib.request
import re
import os

DIR = os.path.dirname(os.path.abspath(__file__))

def fetch_images(url, keywords, out_name):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        html = urllib.request.urlopen(req, timeout=10).read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  FAIL: {e}")
        return

    imgs = re.findall(r'(https?://[^\s"\'<>]+\.(?:jpg|jpeg|png|webp))', html)
    
    found = []
    for img in imgs:
        low = img.lower()
        if any(k in low for k in keywords):
            if img not in found:
                found.append(img)
    
    if not found:
        # Fallback: look for og:image or entry images
        og = re.findall(r'og:image["\s]+content="([^"]+)"', html)
        found.extend(og)
        entry = re.findall(r'(https?://i\.kym-cdn\.com/[^\s"\'<>]+\.(?:jpg|jpeg|png|webp))', html)
        found.extend(entry)

    print(f"  Found {len(found)} candidate images")
    for i, url in enumerate(found[:5]):
        print(f"    [{i}] {url[:120]}")

    if found:
        out_path = os.path.join(DIR, out_name)
        try:
            urllib.request.urlretrieve(found[0], out_path)
            size = os.path.getsize(out_path) // 1024
            print(f"  Saved: {out_path} ({size} KB)")
        except Exception as e:
            print(f"  Download failed: {e}")


print("=== Cappuccino Assassino ===")
fetch_images(
    "https://knowyourmeme.com/memes/cappuccino-assassino-italian-brainrot",
    ["cappuccino", "assassino"],
    "cappuccino-ref.jpg"
)

print("\n=== Tung Tung Tung Sahur ===")
fetch_images(
    "https://knowyourmeme.com/memes/tung-tung-tung-sahur",
    ["tung", "sahur"],
    "tungtung-ref.jpg"
)
