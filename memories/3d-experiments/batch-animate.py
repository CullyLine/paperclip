"""
Batch animate all rigged pets and export animated GLBs.
Runs Blender headless for each pet, generates Idle/Walk/Float animations,
and exports the final GLB with NLA tracks.

Usage: python batch-animate.py
"""
import os, subprocess, sys, json

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
ANIM_SCRIPT = os.path.join(HERE, "universal-animate.py")

TRACKER = os.path.join(HERE, "batch-tracker.json")
with open(TRACKER) as f:
    tracker = json.load(f)

PETS = [name for name in tracker if tracker[name].get("rigged")]

for name in PETS:
    rigged = os.path.join(HERE, f"{name}-game-340_rigged.glb")
    animated = os.path.join(HERE, f"{name}-game-340_animated.glb")

    if not os.path.exists(rigged):
        print(f"[SKIP] {name}: rigged model not found", flush=True)
        continue

    if os.path.exists(animated):
        print(f"[SKIP] {name}: already animated", flush=True)
        tracker[name]["animated"] = True
        tracker[name]["animated_path"] = animated
        with open(TRACKER, "w") as f:
            json.dump(tracker, f, indent=2)
        continue

    print(f"\n[ANIM] {name}: {rigged}", flush=True)
    cmd = [
        BLENDER, "--background", "--python", ANIM_SCRIPT,
        "--", rigged, animated, name,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)

    if os.path.exists(animated):
        size_kb = os.path.getsize(animated) / 1024
        print(f"[OK]   {name}: {size_kb:.0f} KB -> {animated}", flush=True)
        tracker[name]["animated"] = True
        tracker[name]["animated_path"] = animated
    else:
        print(f"[FAIL] {name}: animated GLB not created", flush=True)
        last_lines = r.stdout.strip().split("\n")[-8:]
        for l in last_lines:
            print(f"  OUT: {l}", flush=True)
        if r.stderr:
            err_lines = r.stderr.strip().split("\n")[-5:]
            for l in err_lines:
                print(f"  ERR: {l}", flush=True)
        tracker[name]["animated"] = False

    with open(TRACKER, "w") as f:
        json.dump(tracker, f, indent=2)

print(f"\n{'='*60}", flush=True)
print("=== Animation summary ===", flush=True)
for name in PETS:
    done = "YES" if tracker[name].get("animated") else "NO"
    print(f"  {name}: animated={done}", flush=True)
