"""Convert all 5 rigged brainrot GLBs to .blend files, then open them in Blender GUI."""
import subprocess
import os

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
CONVERT_SCRIPT = os.path.join(DIR, "convert-to-blend.py")

pets = ["tungtung", "bombombini", "tralalero", "bombardiro", "cappuccino"]

for pet in pets:
    glb = os.path.join(DIR, f"{pet}-game-340_rigged.glb")
    blend = os.path.join(DIR, f"{pet}-rigged.blend")

    if not os.path.exists(glb):
        print(f"[SKIP] {pet}: rigged GLB not found")
        continue

    print(f"[CONVERT] {pet} -> .blend")
    result = subprocess.run(
        [BLENDER, "--background", "--python", CONVERT_SCRIPT, "--", glb, blend],
        capture_output=True, text=True, timeout=60
    )

    if os.path.exists(blend):
        size_kb = os.path.getsize(blend) // 1024
        print(f"[OK] {pet}: {size_kb} KB")
    else:
        print(f"[FAIL] {pet}")
        last = result.stderr.strip().split("\\n")[-3:] if result.stderr else []
        for l in last:
            print(f"  {l}")

print("\\nOpening all .blend files...")
for pet in pets:
    blend = os.path.join(DIR, f"{pet}-rigged.blend")
    if os.path.exists(blend):
        print(f"[OPEN] {pet}")
        subprocess.Popen([BLENDER, blend])
