"""Test UniRig skeleton step with GPU eager config on tungtung."""
import subprocess
import os
import shutil
import time

UNIRIG = r"F:\CODE STUFF\tools\UniRig"
VENV_PYTHON = os.path.join(UNIRIG, "venv", "Scripts", "python.exe")
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
MODEL = os.path.join(DIR, "tungtung-game-340.glb")

env = os.environ.copy()
env["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

ts = time.strftime("%Y_%m_%d_%H_%M_%S")
tmp_dir = os.path.join(UNIRIG, "tmp")
results_dir = os.path.join(UNIRIG, "results")
os.makedirs(tmp_dir, exist_ok=True)
os.makedirs(results_dir, exist_ok=True)

adj_dir = os.path.join(DIR, "tungtung-game-340")
if os.path.exists(adj_dir):
    shutil.rmtree(adj_dir)

# Step 1: Extract
print("Step 1: Extract mesh...")
r = subprocess.run([
    VENV_PYTHON, "-m", "src.data.extract",
    "--config=configs/data/quick_inference.yaml",
    "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
    "--force_override=true", "--num_runs=1", "--id=0",
    f"--time={ts}", "--faces_target_count=50000",
    f"--input={MODEL}", f"--output_dir={tmp_dir}"
], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
print(f"  Exit code: {r.returncode} (bpy crash expected)")

npz_check = os.path.join(DIR, "tungtung-game-340", "raw_data.npz")
if os.path.exists(npz_check):
    print(f"  raw_data.npz: {os.path.getsize(npz_check)} bytes")
else:
    print(f"  WARNING: raw_data.npz not found at {npz_check}")

# Step 2: Skeleton with GPU eager config
skel_fbx = os.path.join(results_dir, "tungtung-game-340_skeleton.fbx")
print("\nStep 2: Skeleton (GPU eager, bf16-mixed)...")
r = subprocess.run([
    VENV_PYTHON, os.path.join(UNIRIG, "run.py"),
    "--task=configs/task/quick_inference_skeleton_articulationxl_ar_256_gpu_eager.yaml",
    "--seed=12345",
    f"--input={MODEL}",
    f"--output={skel_fbx}",
    f"--npz_dir={tmp_dir}"
], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=600)

print(f"  Exit code: {r.returncode}")

# Check for errors in output
for line in r.stdout.split("\n"):
    if "error" in line.lower() or "fail" in line.lower() or "oom" in line.lower():
        print(f"  STDOUT: {line.strip()}")
for line in r.stderr.split("\n"):
    if "error" in line.lower() or "fail" in line.lower() or "oom" in line.lower() or "memory" in line.lower():
        print(f"  STDERR: {line.strip()}")

# Check outputs
predict_npz = os.path.join(DIR, "tungtung-game-340", "predict_skeleton.npz")
if os.path.exists(predict_npz):
    print(f"\n  predict_skeleton.npz: {os.path.getsize(predict_npz)} bytes - SUCCESS!")
else:
    print(f"\n  predict_skeleton.npz NOT FOUND")
    # Check alternate locations
    for root, dirs, files in os.walk(UNIRIG):
        for f in files:
            if f == "predict_skeleton.npz":
                full = os.path.join(root, f)
                print(f"  Found at: {full}")

if os.path.exists(skel_fbx):
    print(f"  skeleton.fbx: {os.path.getsize(skel_fbx)} bytes - SUCCESS!")
else:
    print(f"  skeleton.fbx NOT FOUND")

# Print last 10 lines of stdout for context
print("\nLast output lines:")
for line in r.stdout.strip().split("\n")[-10:]:
    print(f"  {line}")
