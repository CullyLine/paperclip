import os
import json
import urllib.request
import urllib.error
import base64
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

XAI_API_KEY = os.environ.get("XAI_API_KEY", "").strip()
if not XAI_API_KEY:
    raise RuntimeError("Set XAI_API_KEY env var")

REF_DIR = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-refs")
OUT_DIR = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-pets-chibi")
REF_DIR.mkdir(parents=True, exist_ok=True)
OUT_DIR.mkdir(parents=True, exist_ok=True)

PETS = [
    ("evil_bob", "Evil Bob the Cat", "Evil_Bob_%28random_event%29.png", "a sinister black cat with glowing yellow eyes, Random Event NPC"),
    ("baby_dragon", "Baby Red Dragon", "Baby_red_dragon.png", "a small red dragon with wings and a tail"),
    ("imp", "Imp", "Imp_%28NPC%29.png", "a tiny red demon with horns, wings, and a pointed tail"),
    ("hellcat", "Hellcat", "Hellcat.png", "a dark red-orange menacing cat with glowing red eyes"),
    ("rock_golem", "Rock Golem", "Rock_golem_%28iron%29_pet.png", "a chunky humanoid made of gray and brown rocks"),
    ("beaver", "Beaver", "Beaver_%28Mahogany%29.png", "a brown beaver with a large flat tail and buck teeth"),
    ("tangleroot", "Tangleroot", "Tangleroot.png", "a small tree creature with leaves for hair and root feet"),
    ("giant_squirrel", "Giant Squirrel", "Giant_squirrel.png", "an oversized red-brown squirrel with a big fluffy tail"),
    ("rocky", "Rocky the Raccoon", "Rocky.png", "a gray raccoon with black mask markings and striped tail"),
    ("heron", "Heron", "Heron_%28pet%29.png", "a tall elegant blue-gray fishing bird with long legs"),
    ("chompy_chick", "Chompy Chick", "Chompy_chick.png", "a round green baby bird with a large beak"),
    ("abyssal_orphan", "Abyssal Orphan", "Abyssal_orphan.png", "a dark purple floating tentacle creature with a single eye"),
    ("noon", "Noon", "Noon.png", "a small stone gargoyle with bat wings"),
    ("vorki", "Vorki", "Vorki.png", "a baby blue-green ice dragon with small wings"),
    ("jad", "TzRek-Jad", "TzRek-Jad.png", "a tiny lava and rock monster with orange glowing cracks"),
    ("chaos_ele_jr", "Chaos Elemental Jr", "Chaos_Elemental_Jr.png", "a swirling multicolored cloud creature"),
    ("prince_black_dragon", "Prince Black Dragon", "Prince_black_dragon.png", "a sleek small black dragon with red eyes"),
    ("kalphite_princess", "Kalphite Princess", "Kalphite_princess.png", "a golden-green insectoid beetle with pincers"),
    ("bloodhound", "Bloodhound", "Bloodhound.png", "a brown and tan detective dog with floppy ears"),
    ("phoenix_pet", "Phoenix", "Phoenix_%28pet%29.png", "a fiery orange-red-gold bird with flaming wings"),
    ("rift_guardian", "Rift Guardian", "Rift_guardian_%28fire%29.png", "a floating arcane creature made of magical energy"),
    ("snakeling", "Pet Snakeling", "Pet_snakeling.png", "a small teal and magenta serpent"),
    ("baby_mole", "Baby Mole", "Baby_mole.png", "a round pink mole with giant front claws"),
    ("olmlet", "Olmlet", "Olmlet.png", "a small crystalline white lizard-dragon creature"),
    ("skotos", "Skotos", "Skotos.png", "a dark floating orb creature with purple shadow energy"),
]

WIKI_BASE = "https://oldschool.runescape.wiki/images/"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

# Step 1: Download reference images
print("=" * 60)
print("STEP 1: Downloading OSRS Wiki reference images")
print("=" * 60)

def download_ref(pet):
    slug, name, wiki_img, desc = pet
    ref_path = REF_DIR / f"{slug}.png"
    if ref_path.exists():
        print(f"  [cached] {name}")
        return slug, True
    
    url = WIKI_BASE + wiki_img
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=15) as resp:
            with open(ref_path, "wb") as f:
                f.write(resp.read())
        print(f"  [ok] {name}")
        return slug, True
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")
        return slug, False

with ThreadPoolExecutor(max_workers=5) as pool:
    results = list(pool.map(download_ref, PETS))

downloaded = {slug for slug, ok in results if ok}
failed = [p for p in PETS if p[0] not in downloaded]
if failed:
    print(f"\n  Failed to download {len(failed)} references: {[p[1] for p in failed]}")
    print("  Will generate those without reference images.")

# Step 2: Generate chibi versions with Grok
print(f"\n{'=' * 60}")
print("STEP 2: Generating chibi pets with Grok (with references)")
print("=" * 60)

def generate_chibi(pet):
    slug, name, wiki_img, desc = pet
    out_path = OUT_DIR / f"{slug}.png"
    if out_path.exists():
        print(f"  [cached] {name}")
        return slug, True
    
    ref_path = REF_DIR / f"{slug}.png"
    has_ref = ref_path.exists()
    
    prompt = (
        f"Transform this character into ONE SINGLE adorable chibi super-deformed Roblox collectible "
        f"pet toy figure. This is {name} from Old School RuneScape — {desc}. "
        f"CHIBI STYLE: oversized head (40-50% of total body), very stubby short limbs, "
        f"round smooth toy-like body. Think Funko Pop or Pet Simulator X pet style. "
        f"Keep the character's key visual features and colors recognizable. "
        f"Big sparkly expressive eyes. Vibrant saturated colors, smooth toy-like surfaces. "
        f"Only ONE character, no text, no labels. "
        f"Centered on pure white background, product photography lighting, studio render, "
        f"front three-quarter view."
    )
    
    if has_ref:
        with open(ref_path, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode("utf-8")
        
        payload = json.dumps({
            "model": "grok-imagine-image",
            "prompt": prompt,
            "image": {
                "url": f"data:image/png;base64,{img_b64}",
                "type": "image_url"
            },
            "response_format": "b64_json"
        }).encode("utf-8")
        endpoint = "https://api.x.ai/v1/images/edits"
    else:
        no_ref_prompt = (
            f"ONE SINGLE adorable chibi super-deformed Roblox collectible pet toy figure "
            f"of {name} from Old School RuneScape. The character is {desc}. "
            f"CHIBI STYLE: oversized head (40-50% of total body), very stubby short limbs, "
            f"round smooth toy-like body. Think Funko Pop or Pet Simulator X pet style. "
            f"Big sparkly expressive eyes. Vibrant saturated colors, smooth toy-like surfaces. "
            f"Only ONE character, no text, no labels. "
            f"Centered on pure white background, product photography lighting, studio render, "
            f"front three-quarter view."
        )
        payload = json.dumps({
            "model": "grok-imagine-image",
            "prompt": no_ref_prompt,
            "response_format": "b64_json"
        }).encode("utf-8")
        endpoint = "https://api.x.ai/v1/images/generations"
    
    req = urllib.request.Request(
        endpoint,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {XAI_API_KEY}"
        },
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode("utf-8"))
        
        if "data" in result and len(result["data"]) > 0:
            img_data = result["data"][0]
            if "b64_json" in img_data:
                with open(out_path, "wb") as f:
                    f.write(base64.b64decode(img_data["b64_json"]))
            elif "url" in img_data:
                urllib.request.urlretrieve(img_data["url"], str(out_path))
            ref_tag = "with ref" if has_ref else "no ref"
            print(f"  [ok] {name} ({ref_tag})")
            return slug, True
        else:
            print(f"  [FAIL] {name}: unexpected response")
            return slug, False
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")[:200]
        print(f"  [FAIL] {name}: HTTP {e.code} — {body}")
        return slug, False
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")
        return slug, False

# Generate with limited concurrency to avoid rate limits
generated = []
with ThreadPoolExecutor(max_workers=3) as pool:
    futures = {pool.submit(generate_chibi, pet): pet for pet in PETS}
    for future in as_completed(futures):
        slug, ok = future.result()
        generated.append((slug, ok))

success = sum(1 for _, ok in generated if ok)
print(f"\n  Generated {success}/{len(PETS)} pets")

# Step 3: Stitch into a 5x5 grid
print(f"\n{'=' * 60}")
print("STEP 3: Stitching into concept sheet")
print("=" * 60)

try:
    from PIL import Image, ImageDraw, ImageFont
    
    cell_size = 512
    cols, rows = 5, 5
    padding = 10
    label_height = 40
    
    sheet_w = cols * (cell_size + padding) + padding
    sheet_h = rows * (cell_size + label_height + padding) + padding
    sheet = Image.new("RGB", (sheet_w, sheet_h), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except:
        font = ImageFont.load_default()
    
    for i, (slug, name, _, _) in enumerate(PETS):
        if i >= 25:
            break
        row = i // cols
        col = i % cols
        x = padding + col * (cell_size + padding)
        y = padding + row * (cell_size + label_height + padding)
        
        img_path = OUT_DIR / f"{slug}.png"
        if img_path.exists():
            img = Image.open(img_path).convert("RGB")
            img = img.resize((cell_size, cell_size), Image.LANCZOS)
            sheet.paste(img, (x, y))
        else:
            draw.rectangle([x, y, x + cell_size, y + cell_size], fill=(220, 220, 220))
            draw.text((x + 10, y + cell_size // 2), f"[missing]", fill=(150, 150, 150), font=font)
        
        text_bbox = draw.textbbox((0, 0), name, font=font)
        text_w = text_bbox[2] - text_bbox[0]
        text_x = x + (cell_size - text_w) // 2
        text_y = y + cell_size + 5
        draw.text((text_x, text_y), name, fill=(30, 30, 30), font=font)
    
    sheet_path = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-pets-concept-sheet-v2.png")
    sheet.save(sheet_path, quality=95)
    print(f"  Saved: {sheet_path}")
    print(f"  Size: {sheet_w}x{sheet_h}")

except ImportError:
    print("  Pillow not installed. Install with: pip install Pillow")
    print("  Individual pet images are in: assets/osrs-pets-chibi/")

print("\nDone!")
