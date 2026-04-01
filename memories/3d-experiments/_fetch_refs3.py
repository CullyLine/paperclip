import urllib.request, os

DIR = os.path.dirname(os.path.abspath(__file__))

def download(url, out_name):
    out = os.path.join(DIR, out_name)
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "image/webp,image/apng,image/*,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://knowyourmeme.com/",
    })
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        data = resp.read()
        with open(out, "wb") as f:
            f.write(data)
        size = len(data) // 1024
        print(f"  OK: {out_name} ({size} KB)")
        return True
    except Exception as e:
        print(f"  FAIL: {url[:80]} -> {e}")
        return False

# Tung Tung from KYM entry icons
print("=== Tung Tung Tung Sahur ===")
urls = [
    "https://i.kym-cdn.com/entries/icons/facebook/000/053/559/tung_tung_tung_sahur.jpg",
    "https://i.kym-cdn.com/entries/icons/mobile/000/053/559/tung_tung_tung_sahur.jpg",
    "https://i.kym-cdn.com/entries/icons/original/000/053/559/tung_tung_tung_sahur.jpg",
    "https://i.kym-cdn.com/entries/icons/medium/000/053/559/tung_tung_tung_sahur.jpg",
]
for url in urls:
    if download(url, "tungtung-ref.jpg"):
        break

# Also get Cappuccino from KYM
print("\n=== Cappuccino Assassino ===")
urls = [
    "https://i.kym-cdn.com/entries/icons/facebook/000/055/332/cappuccino-assassino.jpg",
    "https://i.kym-cdn.com/entries/icons/original/000/055/332/cappuccino-assassino.jpg",
    "https://i.kym-cdn.com/entries/icons/original/000/055/332/dollar-store-cappuccino-assassino.jpg",
    "https://i.kym-cdn.com/entries/icons/facebook/000/055/332/dollar-store-cappuccino-assassino.jpg",
]
for url in urls:
    if download(url, "cappuccino-ref.jpg"):
        break

# Check sizes
for name in ["tungtung-ref.jpg", "cappuccino-ref.jpg"]:
    path = os.path.join(DIR, name)
    if os.path.exists(path):
        print(f"\n{name}: {os.path.getsize(path) // 1024} KB")
    else:
        print(f"\n{name}: MISSING")
