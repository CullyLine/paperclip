import urllib.request
import urllib.error
import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

REF_DIR = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-npc-refs")
REF_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
WIKI_BASE = "https://oldschool.runescape.wiki/images/"

NPCS = [
    ("noob", ["Noob.png", "Bronze_full_helm_equipped.png", "A_Friend_in_Need.png"]),
    ("wise_old_man", ["Wise_Old_Man.png", "Wise_Old_Man_%28id_2253%29.png"]),
    ("hans", ["Hans.png", "Hans_%28NPC%29.png"]),
    ("bob_the_cat", ["Bob_%28cat%29.png", "Bob_the_Cat_%28NPC%29.png", "Bob.png"]),
    ("sandwich_lady", ["Sandwich_Lady.png", "Sandwich_lady.png"]),
    ("genie", ["Genie.png", "Genie_%28random_event%29.png"]),
    ("nieve", ["Nieve.png", "Nieve_chathead.png"]),
    ("zamorak", ["Zamorak.png", "Zamorak_%28God%29.png"]),
    ("saradomin", ["Saradomin.png"]),
    ("guthix", ["Guthix.png", "Guthix_%28God%29.png"]),
    ("king_roald", ["King_Roald.png", "King_Roald_III.png"]),
    ("cook", ["Cook_%28Lumbridge%29.png", "Cook.png"]),
    ("duke_horacio", ["Duke_Horacio.png"]),
    ("lumbridge_guide", ["Lumbridge_Guide.png"]),
    ("party_pete", ["Party_Pete.png"]),
    ("thurgo", ["Thurgo.png"]),
    ("gnome_child", ["Gnome_child.png", "Gnome_Child.png"]),
    ("strange_old_man", ["Strange_Old_Man.png"]),
    ("farmer_fred", ["Fred_the_Farmer.png", "Farmer_Fred.png", "Fred.png"]),
    ("ali_the_wise", ["Ali_the_Wise.png"]),
    ("tzhaar_mej", ["TzHaar-Mej.png", "TzHaar-Mej_%28monster%29.png"]),
    ("monkey_guard", ["Monkey_Guard.png"]),
    ("cave_goblin", ["Cave_goblin_%28monster%29.png", "Cave_goblin.png", "Goblin.png"]),
    ("moss_giant", ["Moss_giant.png", "Moss_giant_%28level_42%29.png"]),
    ("dark_wizard", ["Dark_wizard.png", "Dark_wizard_%28level_7%29.png"]),
]

def download_npc(npc_data):
    slug, filenames = npc_data
    ref_path = REF_DIR / f"{slug}.png"
    if ref_path.exists():
        print(f"  [cached] {slug}")
        return slug, True

    for filename in filenames:
        url = WIKI_BASE + filename
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
                if len(data) > 500:
                    with open(ref_path, "wb") as f:
                        f.write(data)
                    print(f"  [ok] {slug} <- {filename}")
                    return slug, True
        except (urllib.error.HTTPError, urllib.error.URLError):
            continue

    print(f"  [FAIL] {slug} - tried {len(filenames)} URLs")
    return slug, False

print("Downloading OSRS NPC reference images...\n")
with ThreadPoolExecutor(max_workers=5) as pool:
    results = list(pool.map(download_npc, NPCS))

ok = sum(1 for _, s in results if s)
print(f"\nDownloaded {ok}/{len(NPCS)} references")
for slug, success in results:
    if not success:
        print(f"  Missing: {slug}")
