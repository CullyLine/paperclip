import urllib.request
import urllib.error
from pathlib import Path

REF_DIR = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-npc-refs")
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
WIKI_BASE = "https://oldschool.runescape.wiki/images/"

MISSING = {
    "noob": [
        "Bronze_armour_set_%28lg%29_equipped.png",
        "Bronze_armour_%28lg%29_equipped.png",
        "A_Friend_in_Need_%28miniquest%29.png",
        "Bronze_full_helm_detail.png",
        "Tutorial_Island.png",
    ],
    "zamorak": [
        "Zamorak_%28Wilderness_Wars%29.png",
        "K%27ril_Tsutsaroth.png",
        "Zamorak_chathead.png",
        "Zamorak_godsword_detail.png",
        "Zamorak_staff.png",
    ],
    "saradomin": [
        "Saradomin_chathead.png",
        "Saradomin_godsword_detail.png",
        "Commander_Zilyana.png",
    ],
    "guthix": [
        "Guthix_chathead.png",
        "Guthix_staff.png",
        "Balance_elemental.png",
    ],
    "ali_the_wise": [
        "Ali_the_Wise_%28Nardah%29.png",
        "Azzanadra.png",
        "Desert_robes_equipped.png",
    ],
}

for slug, urls in MISSING.items():
    ref_path = REF_DIR / f"{slug}.png"
    if ref_path.exists():
        print(f"  [already exists] {slug}")
        continue
    
    found = False
    for filename in urls:
        url = WIKI_BASE + filename
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
                if len(data) > 500:
                    with open(ref_path, "wb") as f:
                        f.write(data)
                    print(f"  [ok] {slug} <- {filename}")
                    found = True
                    break
        except (urllib.error.HTTPError, urllib.error.URLError):
            continue
    
    if not found:
        print(f"  [FAIL] {slug}")

# Verify all
print("\nFinal check:")
for slug in ["noob", "wise_old_man", "hans", "bob_the_cat", "sandwich_lady",
             "genie", "nieve", "zamorak", "saradomin", "guthix",
             "king_roald", "cook", "duke_horacio", "lumbridge_guide", "party_pete",
             "thurgo", "gnome_child", "strange_old_man", "farmer_fred", "ali_the_wise",
             "tzhaar_mej", "monkey_guard", "cave_goblin", "moss_giant", "dark_wizard"]:
    ref = REF_DIR / f"{slug}.png"
    status = "OK" if ref.exists() else "MISSING"
    print(f"  {slug}: {status}")
