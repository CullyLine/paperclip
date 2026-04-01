"""Batch decimate all highpoly GLBs to ~340 faces using Blender headless."""
import os, subprocess, sys, json

HERE = os.path.dirname(os.path.abspath(__file__))
DECIMATE_SCRIPT = os.path.join(HERE, "..", "..", "decimate.py")
BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
TARGET_FACES = 340
VOXEL_SIZE = 0.032

TRACKER = os.path.join(HERE, "batch-tracker.json")
with open(TRACKER) as f:
    tracker = json.load(f)

PETS = [name for name in tracker if tracker[name].get("downloaded")]

for name in PETS:
    hp = os.path.join(HERE, f"{name}-highpoly.glb")
    lp = os.path.join(HERE, f"{name}-game-340.glb")

    if not os.path.exists(hp):
        print(f"[SKIP] {name}: highpoly not found at {hp}")
        continue

    if os.path.exists(lp):
        print(f"[SKIP] {name}: already decimated")
        tracker[name]["decimated"] = True
        tracker[name]["game_path"] = lp
        continue

    print(f"\n[DECI] {name}: {hp} -> {lp}")
    cmd = [
        BLENDER, "--background", "--python", DECIMATE_SCRIPT,
        "--", hp, lp, str(TARGET_FACES), str(VOXEL_SIZE),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

    if os.path.exists(lp):
        size_kb = os.path.getsize(lp) / 1024
        print(f"[OK]   {name}: {size_kb:.0f} KB")
        tracker[name]["decimated"] = True
        tracker[name]["game_path"] = lp
    else:
        print(f"[FAIL] {name}: output not created")
        last_lines = result.stdout.strip().split("\n")[-5:]
        for l in last_lines:
            print(f"       {l}")
        if result.stderr:
            err_lines = result.stderr.strip().split("\n")[-3:]
            for l in err_lines:
                print(f"  ERR: {l}")
        tracker[name]["decimated"] = False

    with open(TRACKER, "w") as f:
        json.dump(tracker, f, indent=2)

print("\n=== Decimation summary ===")
for name in PETS:
    done = "YES" if tracker[name].get("decimated") else "NO"
    print(f"  {name}: decimated={done}")
