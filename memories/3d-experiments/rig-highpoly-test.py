"""Test: rig from highpoly, merge onto decimated model.

Runs UniRig skeleton+skin on the highpoly GLB (500K faces, internally reduced to 50K),
then merges the resulting rig onto the low-poly game-ready GLB.
"""
import subprocess
import os
import shutil
import time

UNIRIG = r"F:\CODE STUFF\tools\UniRig"
VENV_PY = os.path.join(UNIRIG, "venv", "Scripts", "python.exe")
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"

PET = "tralalero"
HIGHPOLY = os.path.join(DIR, f"{PET}-highpoly.glb")
LOWPOLY = os.path.join(DIR, f"{PET}-game-340.glb")
OUTPUT = os.path.join(DIR, f"{PET}-game-340_rigged_hp.glb")  # hp = highpoly-rigged

os.chdir(UNIRIG)
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

print(f"=== Rig from highpoly test: {PET} ===")
print(f"Highpoly: {HIGHPOLY}")
print(f"Lowpoly target: {LOWPOLY}")
print()

# 1. Extract (from highpoly — UniRig will internally reduce to 50K)
print("[1/5] Extracting from highpoly...")
t0 = time.time()
from datetime import datetime
ts = datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
r = subprocess.run([VENV_PY, "-m", "src.data.extract",
    "--config=configs/data/quick_inference.yaml",
    "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
    "--force_override=true", "--num_runs=1", "--id=0",
    f"--time={ts}",
    "--faces_target_count=50000",
    f"--input={HIGHPOLY}", "--output_dir=tmp"],
    capture_output=True, text=True)
print(f"  Done in {time.time()-t0:.1f}s")
if r.returncode != 0:
    print(f"  STDERR: {r.stderr[-500:]}")

# 2. Skeleton (GPU eager)
print("[2/5] Predicting skeleton (GPU eager)...")
t0 = time.time()
r = subprocess.run([VENV_PY, "run.py",
    "--task=configs/task/quick_inference_skeleton_articulationxl_ar_256_gpu_eager.yaml",
    "--seed=12345",
    f"--input={HIGHPOLY}",
    f"--output=results/{PET}_hp_skeleton.fbx",
    "--npz_dir=tmp"],
    capture_output=True, text=True)
print(f"  Done in {time.time()-t0:.1f}s (exit={r.returncode})")

# 3. Copy predict_skeleton.npz
print("[3/5] Copying skeleton NPZ...")
# Skeleton saves npz in a folder named after the input file (without extension)
# For highpoly input: tralalero-highpoly.glb -> tralalero-highpoly/predict_skeleton.npz
candidates = [
    os.path.join(DIR, f"{PET}-highpoly", "predict_skeleton.npz"),
    os.path.join(DIR, PET, "predict_skeleton.npz"),
    os.path.join(DIR, f"{PET}-game-340", "predict_skeleton.npz"),
]
npz_src = None
for c in candidates:
    if os.path.exists(c):
        npz_src = c
        break
if not npz_src:
    print(f"  ERROR: Can't find predict_skeleton.npz")
    for root, dirs, files in os.walk(DIR):
        for f in files:
            if "predict_skeleton" in f:
                print(f"  Found: {os.path.join(root, f)}")

dst_dir = os.path.join("results", f"{PET}_hp_skeleton")
os.makedirs(dst_dir, exist_ok=True)
if npz_src:
    shutil.copy2(npz_src, os.path.join(dst_dir, "predict_skeleton.npz"))
    print(f"  Copied from {npz_src}")
else:
    print("  FAILED to find npz!")

# 4. Skinning (GPU)
print("[4/5] Skinning (GPU)...")
t0 = time.time()
r = subprocess.run([VENV_PY, "run.py",
    "--task=configs/task/quick_inference_unirig_skin.yaml",
    "--seed=12345",
    f"--input=results/{PET}_hp_skeleton.fbx",
    f"--output=results/{PET}_hp_skin.fbx",
    "--npz_dir=tmp",
    "--data_name=predict_skeleton.npz"],
    capture_output=True, text=True)
print(f"  Done in {time.time()-t0:.1f}s (exit={r.returncode})")

# 5. Merge onto LOW-POLY target (this is the key difference!)
print("[5/5] Merging rig onto low-poly target...")
t0 = time.time()
r = subprocess.run([VENV_PY, "-m", "src.inference.merge",
    "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
    "--num_runs=1", "--id=0",
    f"--source=results/{PET}_hp_skin.fbx",
    f"--target={LOWPOLY}",
    f"--output={OUTPUT}"],
    capture_output=True, text=True)
print(f"  Done in {time.time()-t0:.1f}s (exit={r.returncode})")

if os.path.exists(OUTPUT):
    size = os.path.getsize(OUTPUT) // 1024
    print(f"\nSUCCESS: {OUTPUT} ({size} KB)")
else:
    print(f"\nFAILED: output not created")
    print(f"  STDERR: {r.stderr[-500:]}")

print("\n=== DONE ===")
