"""Rig all 5 brainrot pets with UniRig (CPU skeleton, GPU skinning).

Run from a standalone terminal:
  python rig-brainrot.py
"""
import os
import subprocess
import shutil
import time
import json

UNIRIG = r"F:\CODE STUFF\tools\UniRig"
VENV_PYTHON = os.path.join(UNIRIG, "venv", "Scripts", "python.exe")
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
SEED = 12345
FACES_TARGET = 50000

PETS = ["tungtung", "bombombini", "tralalero", "bombardiro", "cappuccino"]

env = os.environ.copy()
env["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

results_dir = os.path.join(UNIRIG, "results")
tmp_dir = os.path.join(UNIRIG, "tmp")
os.makedirs(results_dir, exist_ok=True)
os.makedirs(tmp_dir, exist_ok=True)

summary = {}

for pet in PETS:
    game_path = os.path.join(DIR, f"{pet}-game-340.glb")
    rigged_path = os.path.join(DIR, f"{pet}-game-340_rigged.glb")
    abs_input = os.path.abspath(game_path)
    base = f"{pet}-game-340"

    if not os.path.exists(game_path):
        print(f"[SKIP] {pet}: game model not found")
        summary[pet] = "SKIPPED"
        continue

    if os.path.exists(rigged_path):
        print(f"[SKIP] {pet}: already rigged")
        summary[pet] = "ALREADY DONE"
        continue

    print(f"\n{'='*60}")
    print(f"[RIG] {pet}")
    print(f"{'='*60}")

    ok = True
    ts = time.strftime("%Y_%m_%d_%H_%M_%S")

    # Clean up any previous extract data
    adj_dir = os.path.join(DIR, base)
    if os.path.exists(adj_dir):
        shutil.rmtree(adj_dir)

    skel_fbx = os.path.join(results_dir, f"{base}_skeleton.fbx")
    skin_fbx = os.path.join(results_dir, f"{base}_skin.fbx")

    # Step 1: Extract mesh
    print(f"  [1/5] Extract mesh...")
    r = subprocess.run([
        VENV_PYTHON, "-m", "src.data.extract",
        "--config=configs/data/quick_inference.yaml",
        "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
        "--force_override=true", "--num_runs=1", "--id=0",
        f"--time={ts}", f"--faces_target_count={FACES_TARGET}",
        f"--input={abs_input}", f"--output_dir={tmp_dir}"
    ], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
    # bpy crash exit code is expected
    raw_npz = os.path.join(DIR, base, "raw_data.npz")
    if os.path.exists(raw_npz):
        print(f"  [1/5] OK: raw_data.npz ({os.path.getsize(raw_npz)} bytes)")
    else:
        print(f"  [1/5] WARN: raw_data.npz not found, skeleton may fail")

    # Step 2: Skeleton (GPU eager, bf16-mixed)
    print(f"  [2/5] Skeleton (GPU eager, bf16)...")
    r = subprocess.run([
        VENV_PYTHON, os.path.join(UNIRIG, "run.py"),
        "--task=configs/task/quick_inference_skeleton_articulationxl_ar_256_gpu_eager.yaml",
        f"--seed={SEED}",
        f"--input={abs_input}",
        f"--output={skel_fbx}",
        f"--npz_dir={tmp_dir}"
    ], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=600)

    if r.returncode != 0:
        print(f"  [2/5] Exit code: {r.returncode}")
        for line in r.stderr.strip().split("\n")[-5:]:
            print(f"    {line}")

    # Check for predict_skeleton.npz
    predict_npz = os.path.join(DIR, base, "predict_skeleton.npz")
    if not os.path.exists(predict_npz):
        print(f"  [2/5] FAIL: predict_skeleton.npz not found")
        # Check for memory errors
        for line in r.stdout.split("\n"):
            if "memory" in line.lower() or "error" in line.lower() or "alloc" in line.lower():
                print(f"    {line.strip()}")
        ok = False
    else:
        print(f"  [2/5] OK: predict_skeleton.npz ({os.path.getsize(predict_npz)} bytes)")

    if ok:
        # Step 3: Copy npz to where skinning expects it
        print(f"  [3/5] Copy npz...")
        skel_noext = os.path.splitext(os.path.basename(skel_fbx))[0]
        npz_target_dir = os.path.join(results_dir, skel_noext)
        os.makedirs(npz_target_dir, exist_ok=True)
        shutil.copy2(predict_npz, os.path.join(npz_target_dir, "predict_skeleton.npz"))
        print(f"  [3/5] OK")

    if ok:
        # Step 4: Skinning (GPU)
        print(f"  [4/5] Skinning (GPU)...")
        try:
            r = subprocess.run([
                VENV_PYTHON, os.path.join(UNIRIG, "run.py"),
                "--task=configs/task/quick_inference_unirig_skin.yaml",
                f"--seed={SEED}",
                f"--input={skel_fbx}",
                f"--output={skin_fbx}",
                f"--npz_dir={tmp_dir}",
                "--data_name=predict_skeleton.npz"
            ], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=1200)
            if r.returncode != 0:
                print(f"  [4/5] Exit code: {r.returncode}")
                for line in r.stderr.strip().split("\n")[-5:]:
                    print(f"    {line}")
                ok = False
            else:
                print(f"  [4/5] OK")
        except subprocess.TimeoutExpired:
            print(f"  [4/5] TIMEOUT (1200s)")
            ok = False

    if ok:
        # Step 5: Merge rig into original model
        print(f"  [5/5] Merge...")
        r = subprocess.run([
            VENV_PYTHON, "-m", "src.inference.merge",
            "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
            "--num_runs=1", "--id=0",
            f"--source={skin_fbx}",
            f"--target={abs_input}",
            f"--output={rigged_path}"
        ], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
        # bpy crash exit code expected

        if os.path.exists(rigged_path):
            size_kb = os.path.getsize(rigged_path) // 1024
            print(f"  [5/5] OK: {rigged_path} ({size_kb} KB)")
            summary[pet] = f"OK ({size_kb} KB)"
        else:
            print(f"  [5/5] FAIL: output not created")
            ok = False

    if not ok:
        summary[pet] = "FAILED"
        print(f"  [FAIL] {pet} rigging failed")

    # Cleanup intermediates
    for f_del in [skel_fbx, skin_fbx]:
        if os.path.exists(f_del):
            os.remove(f_del)
    skel_noext = f"{base}_skeleton"
    npz_cleanup = os.path.join(results_dir, skel_noext)
    if os.path.exists(npz_cleanup):
        shutil.rmtree(npz_cleanup, ignore_errors=True)

print(f"\n{'='*60}")
print("SUMMARY")
print(f"{'='*60}")
for pet, status in summary.items():
    print(f"  {pet}: {status}")
