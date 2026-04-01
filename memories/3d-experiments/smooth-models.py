"""Apply shade smooth + light corrective smooth to all brainrot pet GLBs.

Usage: python smooth-models.py
"""
import subprocess
import os

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
SMOOTH_SCRIPT = os.path.join(DIR, "apply-smooth.py")

pets = ["tungtung", "bombombini", "tralalero", "bombardiro", "cappuccino"]

for pet in pets:
    glb = os.path.join(DIR, f"{pet}-game-340.glb")
    if not os.path.exists(glb):
        print(f"[SKIP] {pet}: not found")
        continue

    print(f"[SMOOTH] {pet}...")
    r = subprocess.run(
        [BLENDER, "--background", "--python", SMOOTH_SCRIPT, "--", glb, glb],
        capture_output=True, text=True, timeout=60
    )
    if r.returncode == 0 or os.path.exists(glb):
        size = os.path.getsize(glb) // 1024
        print(f"[OK]    {pet}: {size} KB")
    else:
        print(f"[FAIL]  {pet}")
        for line in r.stdout.strip().split("\n")[-3:]:
            print(f"  {line}")

print("\nAll done! Models are smoothed in-place.")
