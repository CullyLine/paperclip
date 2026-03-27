"""Batch rig all decimated pets using UniRig (mirrors rig.ps1 steps)."""
import os, subprocess, sys, json, shutil, time

HERE = os.path.dirname(os.path.abspath(__file__))
UNIRIG = r"F:\CODE STUFF\tools\UniRig"
VENV_PYTHON = os.path.join(UNIRIG, "venv", "Scripts", "python.exe")

TRACKER = os.path.join(HERE, "batch-tracker.json")
with open(TRACKER) as f:
    tracker = json.load(f)

PETS = [name for name in tracker if tracker[name].get("decimated")]

env = os.environ.copy()
env["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

SEED = 12345
FACES_TARGET = 50000

for name in PETS:
    game_path = os.path.join(HERE, f"{name}-game-340.glb")
    rigged_path = os.path.join(HERE, f"{name}-game-340_rigged.glb")

    if not os.path.exists(game_path):
        print(f"[SKIP] {name}: game model not found", flush=True)
        continue

    if os.path.exists(rigged_path):
        print(f"[SKIP] {name}: already rigged", flush=True)
        tracker[name]["rigged"] = True
        tracker[name]["rigged_path"] = rigged_path
        with open(TRACKER, "w") as f:
            json.dump(tracker, f, indent=2)
        continue

    print(f"\n{'='*60}", flush=True)
    print(f"[RIG] {name}", flush=True)
    print(f"{'='*60}", flush=True)

    abs_input = os.path.abspath(game_path)
    base = os.path.splitext(os.path.basename(game_path))[0]
    timestamp = time.strftime("%Y_%m_%d_%H_%M_%S")

    results_dir = os.path.join(UNIRIG, "results")
    tmp_dir = os.path.join(UNIRIG, "tmp")
    os.makedirs(results_dir, exist_ok=True)
    os.makedirs(tmp_dir, exist_ok=True)

    skel_fbx = os.path.join(results_dir, f"{base}_skeleton.fbx")
    skin_fbx = os.path.join(results_dir, f"{base}_skin.fbx")

    ok = True

    # Step 1: Extract mesh
    print(f"  [1/4] Extract...", flush=True)
    cmd = [VENV_PYTHON, "-m", "src.data.extract",
           f"--config=configs/data/quick_inference.yaml",
           f"--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
           f"--force_override=true",
           f"--num_runs=1",
           f"--id=0",
           f"--time={timestamp}",
           f"--faces_target_count={FACES_TARGET}",
           f"--input={abs_input}",
           f"--output_dir={tmp_dir}"]
    r = subprocess.run(cmd, cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
    # bpy crash exit code is expected (-1073741819), check if output was created
    print(f"  [1/4] Extract exit code: {r.returncode}", flush=True)

    # Step 2: Skeleton (CPU)
    print(f"  [2/4] Skeleton (CPU)...", flush=True)
    cmd = [VENV_PYTHON, os.path.join(UNIRIG, "run.py"),
           f"--task=configs/task/quick_inference_skeleton_articulationxl_ar_256_cpu.yaml",
           f"--seed={SEED}",
           f"--input={abs_input}",
           f"--output={skel_fbx}",
           f"--npz_dir={tmp_dir}"]
    r = subprocess.run(cmd, cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        print(f"  [FAIL] Skeleton exit: {r.returncode}", flush=True)
        last_err = r.stderr.strip().split("\n")[-5:] if r.stderr else []
        for l in last_err:
            print(f"    ERR: {l}", flush=True)
        ok = False

    if ok:
        # Copy npz to where skin step expects it
        input_parent = os.path.dirname(abs_input)
        input_noext = os.path.splitext(os.path.basename(abs_input))[0]
        npz_source = os.path.join(input_parent, input_noext, "predict_skeleton.npz")

        skel_noext = os.path.splitext(os.path.basename(skel_fbx))[0]
        npz_target_dir = os.path.join(results_dir, skel_noext)
        npz_target = os.path.join(npz_target_dir, "predict_skeleton.npz")

        if os.path.exists(npz_source):
            os.makedirs(npz_target_dir, exist_ok=True)
            shutil.copy2(npz_source, npz_target)
            print(f"  Copied npz: {npz_source} -> {npz_target}", flush=True)
        else:
            print(f"  [WARN] npz not at {npz_source}", flush=True)
            # Try alternate location
            alt_npz = os.path.join(tmp_dir, "predict_skeleton.npz")
            if os.path.exists(alt_npz):
                os.makedirs(npz_target_dir, exist_ok=True)
                shutil.copy2(alt_npz, npz_target)
                print(f"  Copied npz from alt: {alt_npz}", flush=True)
            else:
                print(f"  [FAIL] No predict_skeleton.npz found anywhere", flush=True)
                ok = False

    if ok:
        # Step 3: Skin (GPU)
        print(f"  [3/4] Skin (GPU)...", flush=True)
        cmd = [VENV_PYTHON, os.path.join(UNIRIG, "run.py"),
               f"--task=configs/task/quick_inference_unirig_skin.yaml",
               f"--seed={SEED}",
               f"--input={skel_fbx}",
               f"--output={skin_fbx}",
               f"--npz_dir={tmp_dir}",
               f"--data_name=predict_skeleton.npz"]
        try:
            r = subprocess.run(cmd, cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=1200)
        except subprocess.TimeoutExpired:
            print(f"  [FAIL] Skin timed out after 1200s", flush=True)
            ok = False
            continue
        if r.returncode != 0:
            print(f"  [FAIL] Skin exit: {r.returncode}", flush=True)
            last_err = r.stderr.strip().split("\n")[-5:] if r.stderr else []
            for l in last_err:
                print(f"    ERR: {l}", flush=True)
            ok = False

    if ok:
        # Step 4: Merge
        print(f"  [4/4] Merge...", flush=True)
        cmd = [VENV_PYTHON, "-m", "src.inference.merge",
               f"--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
               f"--num_runs=1",
               f"--id=0",
               f"--source={skin_fbx}",
               f"--target={abs_input}",
               f"--output={rigged_path}"]
        r = subprocess.run(cmd, cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
        # Again, bpy crash exit code is expected

        if os.path.exists(rigged_path):
            size_kb = os.path.getsize(rigged_path) / 1024
            print(f"  [OK] {name} rigged: {size_kb:.0f} KB", flush=True)
            tracker[name]["rigged"] = True
            tracker[name]["rigged_path"] = rigged_path
        else:
            print(f"  [FAIL] Output not created", flush=True)
            last_out = r.stdout.strip().split("\n")[-5:] if r.stdout else []
            for l in last_out:
                print(f"    OUT: {l}", flush=True)
            ok = False

    if not ok:
        tracker[name]["rigged"] = False
        print(f"  [FAIL] {name} rigging failed", flush=True)

    with open(TRACKER, "w") as f:
        json.dump(tracker, f, indent=2)

    # Cleanup intermediates
    for f_del in [skel_fbx, skin_fbx]:
        if os.path.exists(f_del):
            os.remove(f_del)
    skel_noext = os.path.splitext(os.path.basename(skel_fbx))[0] if skel_fbx else ""
    npz_dir_cleanup = os.path.join(results_dir, skel_noext)
    if os.path.exists(npz_dir_cleanup):
        shutil.rmtree(npz_dir_cleanup, ignore_errors=True)
    # Clean input-adjacent npz dir
    adj_dir = os.path.join(os.path.dirname(abs_input), os.path.splitext(os.path.basename(abs_input))[0])
    if os.path.exists(adj_dir):
        shutil.rmtree(adj_dir, ignore_errors=True)

print(f"\n{'='*60}", flush=True)
print("=== Rigging summary ===", flush=True)
for name in PETS:
    done = "YES" if tracker[name].get("rigged") else "NO"
    print(f"  {name}: rigged={done}", flush=True)
