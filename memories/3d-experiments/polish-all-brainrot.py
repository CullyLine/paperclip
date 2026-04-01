"""Polish all 5 brainrot pet models, then open for review.

Usage: python polish-all-brainrot.py
"""
import subprocess
import os

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
POLISH_SCRIPT = os.path.join(DIR, "polish-pet.py")

pets = ["tungtung", "bombombini", "tralalero", "bombardiro", "cappuccino"]

# First re-decimate from highpoly (to undo any previous smoothing)
# Skip bombardiro since user manually edited it
DECIMATE = r"f:\CODE STUFF\Paperclip\decimate.py"
for pet in pets:
    if pet == "bombardiro":
        print(f"[KEEP] {pet}: using user-edited version")
        continue
    highpoly = os.path.join(DIR, f"{pet}-highpoly.glb")
    game = os.path.join(DIR, f"{pet}-game-340.glb")
    if not os.path.exists(highpoly):
        print(f"[SKIP] {pet}: no highpoly")
        continue
    print(f"[DECI] {pet}: fresh decimate from highpoly...")
    os.remove(game) if os.path.exists(game) else None
    subprocess.run([BLENDER, "--background", "--python", DECIMATE, "--", highpoly, game, "340", "0.032"],
        capture_output=True, text=True, timeout=120)
    if os.path.exists(game):
        print(f"[OK]   {pet}: {os.path.getsize(game) // 1024} KB")

print("\n" + "="*50)
print("POLISHING")
print("="*50)

for pet in pets:
    glb = os.path.join(DIR, f"{pet}-game-340.glb")
    if not os.path.exists(glb):
        print(f"[SKIP] {pet}: not found")
        continue

    # Remove old rigged file
    rigged = os.path.join(DIR, f"{pet}-game-340_rigged.glb")
    if os.path.exists(rigged):
        os.remove(rigged)

    print(f"\n[POLISH] {pet}...")
    r = subprocess.run(
        [BLENDER, "--background", "--python", POLISH_SCRIPT, "--", glb, glb],
        capture_output=True, text=True, timeout=120
    )

    # Print relevant output
    for line in r.stdout.split("\n"):
        if line.strip().startswith("[") or "Exported" in line or "Polishing" in line:
            print(f"  {line.strip()}")

    if os.path.exists(glb):
        size = os.path.getsize(glb) // 1024
        print(f"  Result: {size} KB")
    else:
        print(f"  FAIL!")

print("\n" + "="*50)
print("ALL POLISHED! Opening in Blender for review...")
print("="*50)

OPEN_SCRIPT = os.path.join(DIR, "open-glb.py")
for pet in pets:
    glb = os.path.join(DIR, f"{pet}-game-340.glb")
    if os.path.exists(glb):
        subprocess.Popen([BLENDER, "--python", OPEN_SCRIPT, "--", glb])
