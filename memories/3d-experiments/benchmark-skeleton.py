"""Benchmark UniRig skeleton: eager vs flash_attention_2 on GPU.

Run after the main batch finishes:
  python benchmark-skeleton.py
"""
import os
import subprocess
import shutil
import time

UNIRIG = r"F:\CODE STUFF\tools\UniRig"
VENV_PYTHON = os.path.join(UNIRIG, "venv", "Scripts", "python.exe")
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
MODEL = os.path.join(DIR, "tungtung-game-340.glb")

env = os.environ.copy()
env["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

results_dir = os.path.join(UNIRIG, "results")
tmp_dir = os.path.join(UNIRIG, "tmp")

configs = [
    ("GPU eager (current)", "quick_inference_skeleton_articulationxl_ar_256_gpu_eager.yaml"),
    ("GPU flash_attn2 (fast)", "quick_inference_skeleton_articulationxl_ar_256_gpu_fast.yaml"),
]

for name, config in configs:
    print(f"\n{'='*50}")
    print(f"Testing: {name}")
    print(f"{'='*50}")

    adj_dir = os.path.join(DIR, "tungtung-game-340")
    if os.path.exists(adj_dir):
        shutil.rmtree(adj_dir)

    ts = time.strftime("%Y_%m_%d_%H_%M_%S")
    skel_fbx = os.path.join(results_dir, "bench_skeleton.fbx")

    # Extract
    subprocess.run([
        VENV_PYTHON, "-m", "src.data.extract",
        "--config=configs/data/quick_inference.yaml",
        "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
        "--force_override=true", "--num_runs=1", "--id=0",
        f"--time={ts}", "--faces_target_count=50000",
        f"--input={MODEL}", f"--output_dir={tmp_dir}"
    ], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)

    # Skeleton (timed)
    start = time.time()
    r = subprocess.run([
        VENV_PYTHON, os.path.join(UNIRIG, "run.py"),
        f"--task=configs/task/{config}",
        "--seed=12345",
        f"--input={MODEL}",
        f"--output={skel_fbx}",
        f"--npz_dir={tmp_dir}"
    ], cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=300)
    elapsed = time.time() - start

    predict_npz = os.path.join(DIR, "tungtung-game-340", "predict_skeleton.npz")
    if os.path.exists(predict_npz):
        print(f"  Result: SUCCESS in {elapsed:.1f}s")
    else:
        print(f"  Result: FAILED after {elapsed:.1f}s")
        for line in r.stdout.split("\n"):
            if "error" in line.lower() or "memory" in line.lower() or "oom" in line.lower():
                print(f"    {line.strip()}")
        for line in r.stderr.split("\n")[-5:]:
            if line.strip():
                print(f"    {line.strip()}")

    # Cleanup
    if os.path.exists(skel_fbx):
        os.remove(skel_fbx)

print(f"\n{'='*50}")
print("Benchmark complete!")
