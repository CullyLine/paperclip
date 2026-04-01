"""Production pet rigging script: highpoly rig → lowpoly merge → auto-add snout bone.

Usage:
  python rig-pet.py <pet_name>                    # single pet
  python rig-pet.py tungtung bombombini tralalero  # multiple pets
  python rig-pet.py --all                          # all 5 brainrot pets

Expects files in memories/3d-experiments/:
  <pet>-highpoly.glb   (Hunyuan3D output, ~500K faces)
  <pet>-game-340.glb   (decimated + polished, ~340 faces)

Produces:
  <pet>-game-340_rigged.glb  (final rigged model)
"""
import os
import sys
import subprocess
import shutil
import time
import json

UNIRIG = r"F:\CODE STUFF\tools\UniRig"
VENV_PY = os.path.join(UNIRIG, "venv", "Scripts", "python.exe")
BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = r"f:\CODE STUFF\Paperclip\memories\3d-experiments"
SEED = 12345

ALL_PETS = ["tungtung", "bombombini", "tralalero", "bombardiro", "cappuccino"]

env = os.environ.copy()
env["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"


def find_npz(pet_name, highpoly_base):
    """Find predict_skeleton.npz — it could be in several locations."""
    candidates = [
        os.path.join(DIR, highpoly_base, "predict_skeleton.npz"),
        os.path.join(DIR, f"{pet_name}-highpoly", "predict_skeleton.npz"),
        os.path.join(DIR, pet_name, "predict_skeleton.npz"),
        os.path.join(DIR, f"{pet_name}-game-340", "predict_skeleton.npz"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def copy_npz_to_all_locations(npz_src, skeleton_name):
    """Copy npz to both places skinning might look for it."""
    locations = [
        os.path.join(UNIRIG, "results", skeleton_name),
        os.path.join(UNIRIG, "tmp", "results", skeleton_name),
    ]
    for loc in locations:
        os.makedirs(loc, exist_ok=True)
        shutil.copy2(npz_src, os.path.join(loc, "predict_skeleton.npz"))
    return True


def auto_add_snout_bone(rigged_glb, output_glb):
    """Add a snout bone to the rigged model by finding the frontmost bone and extending it."""
    script = r'''
import bpy, sys, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
input_path, output_path = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

armature = None
mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH' and any(m.type == 'ARMATURE' for m in obj.modifiers):
        mesh_obj = obj

if not armature or not mesh_obj:
    print("ERROR: No armature or skinned mesh")
    sys.exit(1)

# Find the mesh's frontmost point (most negative Y typically = front/nose)
mesh = mesh_obj.data
wm = mesh_obj.matrix_world
verts = [wm @ v.co for v in mesh.vertices]
front_vert = min(verts, key=lambda v: v.y)

# Find the bone whose head or tail is closest to the front of the mesh
bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

best_bone = None
best_dist = float('inf')
for ebone in armature.data.edit_bones:
    for pt in [ebone.head, ebone.tail]:
        d = (pt - front_vert).length
        if d < best_dist:
            best_dist = d
            best_bone = ebone

if not best_bone:
    print("ERROR: No bones found")
    bpy.ops.object.mode_set(mode='OBJECT')
    sys.exit(1)

# Check if a snout bone already exists close enough to the front
front_bone_tip = min([best_bone.head, best_bone.tail], key=lambda p: p.y)
front_y = front_vert.y

if abs(front_bone_tip.y - front_y) < 0.02:
    print(f"Snout already covered by {best_bone.name}, skipping")
    bpy.ops.object.mode_set(mode='OBJECT')
else:
    # Create snout bone extending from nearest bone toward front of mesh
    snout = armature.data.edit_bones.new("snout")
    snout.head = Vector(front_bone_tip)
    snout.tail = Vector((front_vert.x, front_vert.y - 0.03, front_vert.z))
    snout.parent = best_bone
    print(f"Added snout bone: parent={best_bone.name}")
    bpy.ops.object.mode_set(mode='OBJECT')

    # Transfer weights for snout
    parent_group = mesh_obj.vertex_groups.get(best_bone.name)
    snout_group = mesh_obj.vertex_groups.new(name="snout")
    snout_head = Vector(front_bone_tip)
    snout_tail = Vector((front_vert.x, front_vert.y - 0.03, front_vert.z))
    snout_center = (snout_head + snout_tail) / 2
    bone_len = (snout_tail - snout_head).length
    radius = max(bone_len * 2.0, 0.06)

    assigned = 0
    for v in mesh.vertices:
        v_pos = wm @ v.co
        dist = min((v_pos - snout_head).length, (v_pos - snout_tail).length, (v_pos - snout_center).length)
        if dist > radius:
            continue
        weight = max(0.0, 1.0 - (dist / radius)) ** 0.5
        if parent_group:
            try:
                pw = parent_group.weight(v.index)
            except RuntimeError:
                pw = 0.0
            if pw > 0:
                transfer = pw * weight * 0.5
                snout_group.add([v.index], transfer, 'REPLACE')
                parent_group.add([v.index], pw - transfer, 'REPLACE')
                assigned += 1
        else:
            snout_group.add([v.index], weight * 0.4, 'REPLACE')
            assigned += 1
    print(f"  Snout weights: {assigned} vertices")

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported: {output_path}")
'''

    script_path = os.path.join(DIR, "_tmp_snout.py")
    with open(script_path, 'w') as f:
        f.write(script)

    r = subprocess.run([BLENDER, "--background", "--python", script_path, "--",
                        rigged_glb, output_glb],
                       capture_output=True, text=True, timeout=30)

    os.remove(script_path)

    for line in r.stdout.split("\n"):
        line = line.strip()
        if line and ("snout" in line.lower() or "added" in line.lower() or
                     "exported" in line.lower() or "error" in line.lower() or
                     "covered" in line.lower()):
            print(f"  {line}")

    return os.path.exists(output_glb)


def rig_pet(pet):
    highpoly = os.path.join(DIR, f"{pet}-highpoly.glb")
    lowpoly = os.path.join(DIR, f"{pet}-game-340.glb")
    output = os.path.join(DIR, f"{pet}-game-340_rigged.glb")

    if not os.path.exists(highpoly):
        print(f"  ERROR: {pet}-highpoly.glb not found")
        return False
    if not os.path.exists(lowpoly):
        print(f"  ERROR: {pet}-game-340.glb not found")
        return False

    # Remove old rigged file
    if os.path.exists(output):
        os.remove(output)

    os.chdir(UNIRIG)
    ts = time.strftime("%Y_%m_%d_%H_%M_%S")
    hp_base = f"{pet}-highpoly"
    skel_name = f"{pet}_hp_skeleton"
    skel_fbx = os.path.join("results", f"{skel_name}.fbx")
    skin_fbx = os.path.join("results", f"{pet}_hp_skin.fbx")

    # Clean previous extracts
    for d in [os.path.join(DIR, hp_base), os.path.join(DIR, pet)]:
        if os.path.exists(d):
            shutil.rmtree(d, ignore_errors=True)

    # Step 1: Extract from highpoly
    print(f"  [1/6] Extract from highpoly...")
    t0 = time.time()
    subprocess.run([VENV_PY, "-m", "src.data.extract",
        "--config=configs/data/quick_inference.yaml",
        "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
        "--force_override=true", "--num_runs=1", "--id=0",
        f"--time={ts}", "--faces_target_count=50000",
        f"--input={highpoly}", "--output_dir=tmp"],
        cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
    print(f"  [1/6] Done ({time.time()-t0:.1f}s)")

    # Step 2: Skeleton (GPU eager)
    print(f"  [2/6] Skeleton (GPU eager)...")
    t0 = time.time()
    subprocess.run([VENV_PY, "run.py",
        "--task=configs/task/quick_inference_skeleton_articulationxl_ar_256_gpu_eager.yaml",
        f"--seed={SEED}", f"--input={highpoly}",
        f"--output={skel_fbx}", "--npz_dir=tmp"],
        cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=600)
    print(f"  [2/6] Done ({time.time()-t0:.1f}s)")

    # Step 3: Copy npz to BOTH locations
    print(f"  [3/6] Copy NPZ...")
    npz_src = find_npz(pet, hp_base)
    if not npz_src:
        print(f"  [3/6] FAIL: predict_skeleton.npz not found!")
        return False
    copy_npz_to_all_locations(npz_src, skel_name)
    print(f"  [3/6] OK (copied from {npz_src})")

    # Step 4: Skinning (GPU)
    print(f"  [4/6] Skinning (GPU)...")
    t0 = time.time()
    r = subprocess.run([VENV_PY, "run.py",
        "--task=configs/task/quick_inference_unirig_skin.yaml",
        f"--seed={SEED}", f"--input={skel_fbx}",
        f"--output={skin_fbx}", "--npz_dir=tmp",
        "--data_name=predict_skeleton.npz"],
        cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=600)
    if not os.path.exists(skin_fbx):
        print(f"  [4/6] FAIL: skin FBX not created")
        return False
    print(f"  [4/6] Done ({time.time()-t0:.1f}s)")

    # Step 5: Merge onto lowpoly
    print(f"  [5/6] Merge onto lowpoly...")
    t0 = time.time()
    tmp_rigged = output + ".tmp"
    subprocess.run([VENV_PY, "-m", "src.inference.merge",
        "--require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm",
        "--num_runs=1", "--id=0",
        f"--source={skin_fbx}", f"--target={lowpoly}",
        f"--output={tmp_rigged}"],
        cwd=UNIRIG, env=env, capture_output=True, text=True, timeout=120)
    if not os.path.exists(tmp_rigged):
        print(f"  [5/6] FAIL: merge output not created")
        return False
    print(f"  [5/6] Done ({time.time()-t0:.1f}s)")

    # Step 6: Auto-add snout bone
    print(f"  [6/6] Adding snout bone...")
    if auto_add_snout_bone(tmp_rigged, output):
        os.remove(tmp_rigged)
        size = os.path.getsize(output) // 1024
        print(f"  [6/6] Done ({size} KB)")
    else:
        shutil.move(tmp_rigged, output)
        print(f"  [6/6] Snout addition failed, using rig without snout")

    # Cleanup
    for f in [skel_fbx, skin_fbx]:
        if os.path.exists(f):
            os.remove(f)

    return True


if __name__ == "__main__":
    pets = sys.argv[1:] if len(sys.argv) > 1 else []
    if "--all" in pets:
        pets = ALL_PETS

    if not pets:
        print("Usage: python rig-pet.py <pet_name> [pet_name2 ...]")
        print("       python rig-pet.py --all")
        sys.exit(1)

    print(f"Rigging {len(pets)} pets: {', '.join(pets)}")
    print(f"Strategy: highpoly rig -> lowpoly merge -> auto snout bone\n")

    results = {}
    for pet in pets:
        print(f"\n{'='*60}")
        print(f"  {pet.upper()}")
        print(f"{'='*60}")
        ok = rig_pet(pet)
        results[pet] = "OK" if ok else "FAILED"

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for pet, status in results.items():
        print(f"  {pet}: {status}")
