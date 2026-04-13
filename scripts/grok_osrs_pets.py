import os
import json
import urllib.request
import urllib.error
import base64
from pathlib import Path

XAI_API_KEY = os.environ.get("XAI_API_KEY", "").strip()
if not XAI_API_KEY:
    raise RuntimeError("Set XAI_API_KEY env var")

pets = [
    "Evil Bob the Cat (black cat with glowing eyes)",
    "Baby Red Dragon (small red dragon hatchling)",
    "Imp (tiny red demon with horns and tail)",
    "Hellcat (dark red-orange sinister cat)",
    "Rock Golem (chunky stone creature with gem eyes)",
    "Beaver (brown beaver with big flat tail)",
    "Tangleroot (small tree creature with leaf hair)",
    "Giant Squirrel (oversized fluffy red squirrel)",
    "Rocky the Raccoon (gray raccoon with mask markings)",
    "Heron (elegant blue-gray fishing bird)",
    "Chompy Chick (round green baby bird)",
    "Abyssal Orphan (dark purple tentacle creature)",
    "Baby Gargoyle (small stone winged creature)",
    "Vorki (baby blue ice dragon)",
    "TzRek-Jad (tiny lava monster with rock armor)",
    "Chaos Elemental Jr (swirling purple cloud creature)",
    "Prince Black Dragon (sleek black baby dragon)",
    "Kalphite Princess (golden beetle with pincers)",
    "Bloodhound (detective dog with magnifying glass)",
    "Phoenix (fiery orange-gold bird)",
    "Rift Guardian (floating arcane eye creature)",
    "Snakeling (small teal and magenta serpent)",
    "Baby Mole (round pink mole with big claws)",
    "Olmlet (small crystalline lizard creature)",
    "Dark Core (floating dark orb with purple energy)"
]

pet_list = ", ".join([f"{i+1}. {p.split('(')[0].strip()}" for i, p in enumerate(pets)])
pet_descriptions = "; ".join(pets)

prompt = f"""A concept art reference sheet showing exactly 25 adorable chibi super-deformed collectible pet toy figures arranged in a 5x5 grid on a pure white background. Each pet is inspired by Old School RuneScape monsters and pets, rendered in Roblox Pet Simulator X / Funko Pop toy style.

Every pet has: oversized head (40-50% of body), very stubby short limbs, round smooth toy-like body, big sparkly expressive eyes, vibrant saturated colors. They look like squishy vinyl collectible figures.

The 25 pets in order (left to right, top to bottom):
{pet_descriptions}

Each pet is labeled with a small clean text name below it. Product photography lighting, studio render, centered composition. Clean white background, no other decorations. Every pet clearly distinct and recognizable."""

print(f"Generating concept art sheet with Grok Imagine...")
print(f"Prompt length: {len(prompt)} chars\n")

payload = json.dumps({
    "model": "grok-2-image",
    "prompt": prompt,
    "n": 1,
    "quality": "high",
    "response_format": "b64_json"
}).encode("utf-8")

req = urllib.request.Request(
    "https://api.x.ai/v1/images/generations",
    data=payload,
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {XAI_API_KEY}"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    
    if "data" in result and len(result["data"]) > 0:
        img_data = result["data"][0]
        
        if "b64_json" in img_data:
            out_path = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-pets-concept-sheet.png")
            out_path.parent.mkdir(parents=True, exist_ok=True)
            with open(out_path, "wb") as f:
                f.write(base64.b64decode(img_data["b64_json"]))
            print(f"Saved to: {out_path}")
        elif "url" in img_data:
            url = img_data["url"]
            out_path = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-pets-concept-sheet.png")
            out_path.parent.mkdir(parents=True, exist_ok=True)
            urllib.request.urlretrieve(url, str(out_path))
            print(f"Saved to: {out_path}")
        
        if "revised_prompt" in img_data:
            print(f"\nRevised prompt: {img_data['revised_prompt'][:200]}...")
    else:
        print(f"Unexpected response: {json.dumps(result, indent=2)[:500]}")

except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8")
    print(f"HTTP {e.code} error:")
    print(body[:500])
    
    if "grok-2-image" in body or "model" in body.lower():
        print("\nTrying with 'grok-imagine-image' model name instead...")
        payload2 = json.dumps({
            "model": "grok-imagine-image",
            "prompt": prompt,
            "n": 1,
            "quality": "high",
            "response_format": "b64_json"
        }).encode("utf-8")
        
        req2 = urllib.request.Request(
            "https://api.x.ai/v1/images/generations",
            data=payload2,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {XAI_API_KEY}"
            },
            method="POST"
        )
        try:
            with urllib.request.urlopen(req2, timeout=120) as resp2:
                result2 = json.loads(resp2.read().decode("utf-8"))
            if "data" in result2 and len(result2["data"]) > 0:
                img_data = result2["data"][0]
                if "b64_json" in img_data:
                    out_path = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-pets-concept-sheet.png")
                    out_path.parent.mkdir(parents=True, exist_ok=True)
                    with open(out_path, "wb") as f:
                        f.write(base64.b64decode(img_data["b64_json"]))
                    print(f"Saved to: {out_path}")
                elif "url" in img_data:
                    url = img_data["url"]
                    out_path = Path(r"f:\CODE STUFF\Paperclip\assets\osrs-pets-concept-sheet.png")
                    out_path.parent.mkdir(parents=True, exist_ok=True)
                    urllib.request.urlretrieve(url, str(out_path))
                    print(f"Saved to: {out_path}")
        except urllib.error.HTTPError as e2:
            print(f"Second attempt also failed: HTTP {e2.code}")
            print(e2.read().decode("utf-8")[:500])

except Exception as e:
    print(f"Error: {e}")
