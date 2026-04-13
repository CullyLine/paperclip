import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

REF_DIR = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-creature-refs")
REF_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
WIKI_BASE = "https://oldschool.runescape.wiki/images/"

# 40 creature candidates (no humans/humanoids) — we need 25 to succeed
CREATURES = [
    ("king_black_dragon", "King Black Dragon", ["King_Black_Dragon.png"]),
    ("kalphite_queen", "Kalphite Queen", ["Kalphite_Queen.png", "Kalphite_Queen_%282nd_form%29.png"]),
    ("giant_mole", "Giant Mole", ["Giant_Mole.png"]),
    ("dagannoth_rex", "Dagannoth Rex", ["Dagannoth_Rex.png"]),
    ("zulrah", "Zulrah", ["Zulrah_%28serpentine%29.png", "Zulrah.png"]),
    ("vorkath", "Vorkath", ["Vorkath.png"]),
    ("jad", "TzTok-Jad", ["TzTok-Jad.png"]),
    ("corporeal_beast", "Corporeal Beast", ["Corporeal_Beast.png"]),
    ("abyssal_demon", "Abyssal Demon", ["Abyssal_demon.png"]),
    ("hellhound", "Hellhound", ["Hellhound.png"]),
    ("black_dragon", "Black Dragon", ["Black_dragon.png"]),
    ("green_dragon", "Green Dragon", ["Green_dragon.png"]),
    ("blue_dragon", "Blue Dragon", ["Blue_dragon.png"]),
    ("red_dragon", "Red Dragon", ["Red_dragon.png"]),
    ("basilisk_knight", "Basilisk Knight", ["Basilisk_Knight.png"]),
    ("hydra", "Alchemical Hydra", ["Alchemical_Hydra_%28serpentine%29.png", "Alchemical_Hydra.png"]),
    ("kraken", "Kraken", ["Kraken.png"]),
    ("cerberus", "Cerberus", ["Cerberus.png"]),
    ("scorpia", "Scorpia", ["Scorpia.png"]),
    ("chaos_fanatic", "Chaos Fanatic", ["Chaos_Fanatic.png"]),
    ("giant_rat", "Giant Rat", ["Giant_rat.png"]),
    ("rock_crab", "Rock Crab", ["Rock_Crab.png", "Rock_crab.png"]),
    ("cave_crawler", "Cave Crawler", ["Cave_crawler.png"]),
    ("bloodveld", "Bloodveld", ["Bloodveld.png"]),
    ("gargoyle", "Gargoyle", ["Gargoyle.png"]),
    ("wyvern", "Skeletal Wyvern", ["Skeletal_Wyvern.png", "Skeletal_wyvern.png"]),
    ("dark_beast", "Dark Beast", ["Dark_beast.png"]),
    ("greater_demon", "Greater Demon", ["Greater_demon.png"]),
    ("black_demon", "Black Demon", ["Black_demon.png"]),
    ("fire_giant", "Fire Giant", ["Fire_giant.png"]),
    ("spider", "Giant Spider", ["Giant_spider.png", "Giant_Spider.png"]),
    ("kbd_pet", "Baby KBD", ["Prince_black_dragon.png"]),
    ("dust_devil", "Dust Devil", ["Dust_devil.png"]),
    ("kurask", "Kurask", ["Kurask.png"]),
    ("cockatrice", "Cockatrice", ["Cockatrice.png"]),
    ("basilisk", "Basilisk", ["Basilisk.png"]),
    ("bear", "Bear", ["Bear.png", "Bear_%28level_19%29.png", "Black_bear.png"]),
    ("cow", "Cow", ["Cow.png"]),
    ("chicken", "Chicken", ["Chicken.png"]),
    ("unicorn", "Unicorn", ["Unicorn.png"]),
    ("snakeling_boss", "Snakeling", ["Snakeling.png"]),
    ("smoke_devil", "Smoke Devil", ["Smoke_devil.png"]),
    ("lizardman", "Lizardman", ["Lizardman.png"]),
    ("wyrm", "Wyrm", ["Wyrm.png"]),
    ("drake", "Drake", ["Drake.png"]),
    ("goblin", "Goblin", ["Goblin.png"]),
]

def download(creature):
    slug, name, filenames = creature
    ref_path = REF_DIR / f"{slug}.png"
    if ref_path.exists():
        return slug, name, True

    for filename in filenames:
        url = WIKI_BASE + filename
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
                if len(data) > 500:
                    with open(ref_path, "wb") as f:
                        f.write(data)
                    return slug, name, True
        except (urllib.error.HTTPError, urllib.error.URLError):
            continue
    return slug, name, False

print("Downloading OSRS creature references...\n")
with ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(download, CREATURES))

succeeded = [(slug, name) for slug, name, ok in results if ok]
failed = [(slug, name) for slug, name, ok in results if not ok]

print(f"\nDownloaded: {len(succeeded)}/{len(CREATURES)}")
if failed:
    print(f"Failed: {[n for _, n in failed]}")

# Pick first 25 that succeeded
final_25 = succeeded[:25]
print(f"\nFinal 25 creatures:")
for i, (slug, name) in enumerate(final_25, 1):
    print(f"  {i:2}. {name} ({slug})")

# Save the list for the next step
import json
out_json = REF_DIR / "creature_list.json"
with open(out_json, "w") as f:
    json.dump(final_25, f, indent=2)
print(f"\nSaved creature list to {out_json}")
