import urllib.request, os

DIR = os.path.dirname(os.path.abspath(__file__))

def download(url, out_name):
    out = os.path.join(DIR, out_name)
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "image/webp,image/apng,image/*,*/*;q=0.8",
        "Referer": "https://www.google.com/",
    })
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        data = resp.read()
        with open(out, "wb") as f:
            f.write(data)
        size = len(data) // 1024
        print(f"  OK: {out} ({size} KB)")
        return True
    except Exception as e:
        print(f"  FAIL: {e}")
        return False

# Cappuccino - already got one, but let's get a better one
print("=== Cappuccino Assassino ===")
cappuccino_urls = [
    "https://i.kym-cdn.com/entries/icons/medium/000/055/332/dollar-store-cappuccino-assassino.jpg",
    "https://i.kym-cdn.com/entries/icons/original/000/055/332/dollar-store-cappuccino-assassino.jpg",
]
for url in cappuccino_urls:
    if download(url, "cappuccino-ref.jpg"):
        break

# Tung Tung - try various sources
print("\n=== Tung Tung Tung Sahur ===")
tungtung_urls = [
    "https://i.kym-cdn.com/entries/icons/original/000/055/185/tungtung.jpg",
    "https://i.kym-cdn.com/entries/icons/medium/000/055/185/tungtung.jpg",
    "https://i.kym-cdn.com/photos/images/original/003/084/000/d91.jpg",
    "https://i.kym-cdn.com/photos/images/medium/003/084/000/d91.jpg",
]
for url in tungtung_urls:
    if download(url, "tungtung-ref.jpg"):
        break

# Check what we have
for name in ["cappuccino-ref.jpg", "tungtung-ref.jpg"]:
    path = os.path.join(DIR, name)
    if os.path.exists(path):
        print(f"\n{name}: {os.path.getsize(path) // 1024} KB")
    else:
        print(f"\n{name}: MISSING")
