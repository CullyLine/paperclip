import urllib.request, re, os

DIR = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(DIR, "tungtung-ref.jpg")

sources = [
    "http://tung-tung-tung-sahur.com/",
    "https://italian-brainrot.org/characters/tung-tung-tung-sahur",
    "https://tungtungtungshur.com/",
]

for url in sources:
    print(f"Trying {url}...")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        html = urllib.request.urlopen(req, timeout=10).read().decode("utf-8", errors="replace")
        imgs = re.findall(r'(https?://[^\s"\'<>]+\.(?:jpg|jpeg|png|webp|gif))', html)
        for img in imgs:
            low = img.lower()
            if "tung" in low or "sahur" in low or "character" in low or "hero" in low:
                print(f"  Found: {img[:120]}")
                try:
                    urllib.request.urlretrieve(img, out)
                    size = os.path.getsize(out) // 1024
                    print(f"  Saved: {out} ({size} KB)")
                    exit(0)
                except Exception as e:
                    print(f"  Download failed: {e}")
        
        # Fallback: og:image
        og = re.findall(r'content="(https?://[^"]+\.(?:jpg|jpeg|png|webp))"', html)
        for img in og:
            print(f"  OG image: {img[:120]}")
            try:
                urllib.request.urlretrieve(img, out)
                size = os.path.getsize(out) // 1024
                print(f"  Saved: {out} ({size} KB)")
                exit(0)
            except Exception as e:
                print(f"  Download failed: {e}")

        # Just try first reasonable image
        for img in imgs[:5]:
            if "logo" not in img.lower() and "icon" not in img.lower() and "favicon" not in img.lower():
                print(f"  Trying first image: {img[:120]}")
                try:
                    urllib.request.urlretrieve(img, out)
                    size = os.path.getsize(out) // 1024
                    if size > 10:
                        print(f"  Saved: {out} ({size} KB)")
                        exit(0)
                except Exception as e:
                    print(f"  Download failed: {e}")

    except Exception as e:
        print(f"  Error: {e}")

print("All sources failed")
