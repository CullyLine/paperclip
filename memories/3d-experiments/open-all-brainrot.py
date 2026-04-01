"""Open all 5 brainrot pet GLBs in separate Blender instances for visual inspection."""
import subprocess
import os

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
SCRIPT = os.path.join(DIR, "open-glb.py")

pets = ["tungtung", "bombombini", "tralalero", "bombardiro", "cappuccino"]

for pet in pets:
    glb = os.path.join(DIR, f"{pet}-game-340.glb")
    if not os.path.exists(glb):
        print(f"[SKIP] {pet}: not found")
        continue
    print(f"[OPEN] {pet}")
    subprocess.Popen([BLENDER, "--python", SCRIPT, "--", glb])
