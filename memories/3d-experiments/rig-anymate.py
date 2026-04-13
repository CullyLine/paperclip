"""Production pet rigging via Anymate (HuggingFace API).

Usage:
  python rig-anymate.py <pet_name>
  python rig-anymate.py tungtung bombombini tralalero
  python rig-anymate.py --all

Expects in memories/3d-experiments/:
  <pet>-game-340.glb   (decimated + polished, ~340 faces)

Produces:
  <pet>-game-340_rigged.glb  (final rigged model with snout bone)
  <pet>-anymate.blend        (cached Anymate output, reused on reruns)
"""
import os, sys, subprocess, shutil, time

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = os.path.dirname(os.path.abspath(__file__))

ALL_PETS = ["tungtung", "StoreTungTung", "bombombini", "tralalero", "bombardiro", "cappuccino"]


# ---------------------------------------------------------------------------
# Step 1: Submit to Anymate API (or reuse cached .blend)
# ---------------------------------------------------------------------------
def anymate_rig(pet, game_glb):
    """Submit game GLB to Anymate and return path to .blend, or None."""
    blend_out = os.path.join(DIR, f"{pet}-anymate.blend")

    if os.path.exists(blend_out):
        print(f"  [1/4] Using cached {pet}-anymate.blend")
        return blend_out

    print(f"  [1/4] Submitting to Anymate API...")
    t0 = time.time()

    from gradio_client import Client, handle_file
    hf_token = os.environ.get("HF_TOKEN")
    client = Client("yfdeng/Anymate", token=hf_token)

    client.predict(mesh_file=handle_file(game_glb), api_name="/process_input")
    client.predict(eps=0.03, min_samples=1, api_name="/get_all_results")
    client.predict(api_name="/vis_all")
    blend_result = client.predict(api_name="/prepare_blender_file")

    elapsed = time.time() - t0

    if blend_result and os.path.exists(blend_result):
        shutil.copy2(blend_result, blend_out)
        print(f"  [1/4] Done ({elapsed:.1f}s) → {pet}-anymate.blend")
        return blend_out
    else:
        print(f"  [1/4] FAIL: Anymate returned no .blend")
        return None


# ---------------------------------------------------------------------------
# Step 2: Merge Anymate armature onto our textured game mesh (Blender)
# ---------------------------------------------------------------------------
MERGE_SCRIPT = r'''
import bpy, sys, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
blend_path, game_glb, output_glb = argv[0], argv[1], argv[2]


def get_bbox(obj):
    """Get world-space bounding box center and size."""
    wm = obj.matrix_world
    verts = [wm @ Vector(c) for c in obj.bound_box]
    xs = [v.x for v in verts]
    ys = [v.y for v in verts]
    zs = [v.z for v in verts]
    mn = Vector((min(xs), min(ys), min(zs)))
    mx = Vector((max(xs), max(ys), max(zs)))
    center = (mn + mx) / 2
    size = mx - mn
    return center, size, mn, mx


# --- Load Anymate .blend ---
bpy.ops.wm.open_mainfile(filepath=blend_path)

anymate_arm = None
anymate_mesh = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        anymate_arm = obj
    elif obj.type == 'MESH':
        anymate_mesh = obj

if not anymate_arm:
    print("ERROR: No armature in .blend")
    sys.exit(1)

# --- Import our game mesh ---
bpy.ops.import_scene.gltf(filepath=game_glb)

game_mesh = None
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj != anymate_mesh:
        game_mesh = obj
        break

if not game_mesh:
    print("ERROR: Game mesh not imported")
    sys.exit(1)

print(f"Anymate armature: {anymate_arm.name} ({len(anymate_arm.data.bones)} bones)")
print(f"Anymate mesh: {anymate_mesh.name} ({len(anymate_mesh.data.vertices)} verts)")
print(f"Game mesh: {game_mesh.name} ({len(game_mesh.data.vertices)} verts)")

# --- Align armature to game mesh coordinate space ---
a_center, a_size, _, _ = get_bbox(anymate_mesh)
g_center, g_size, _, _ = get_bbox(game_mesh)

print(f"Anymate bbox center: ({a_center.x:.3f}, {a_center.y:.3f}, {a_center.z:.3f}) size: ({a_size.x:.3f}, {a_size.y:.3f}, {a_size.z:.3f})")
print(f"Game bbox center: ({g_center.x:.3f}, {g_center.y:.3f}, {g_center.z:.3f}) size: ({g_size.x:.3f}, {g_size.y:.3f}, {g_size.z:.3f})")

# Compute uniform scale factor (use the largest axis to avoid distortion)
a_max_dim = max(a_size.x, a_size.y, a_size.z, 0.0001)
g_max_dim = max(g_size.x, g_size.y, g_size.z, 0.0001)
scale_factor = g_max_dim / a_max_dim
print(f"Scale factor: {scale_factor:.4f}")

# Unparent Anymate mesh from armature temporarily so we can transform armature independently
if anymate_mesh.parent == anymate_arm:
    bpy.ops.object.select_all(action='DESELECT')
    anymate_mesh.select_set(True)
    bpy.context.view_layer.objects.active = anymate_mesh
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')

# Transform the armature: scale around Anymate center, then translate to game center
bpy.ops.object.select_all(action='DESELECT')
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm

# Move armature origin to Anymate mesh center, scale, then move to game mesh center
# Step 1: translate so Anymate center is at origin
anymate_arm.location -= a_center
# Step 2: scale
anymate_arm.scale *= scale_factor
# Step 3: apply transforms
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Step 4: translate to game mesh center
anymate_arm.location = g_center
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

print(f"Armature aligned to game mesh (scale={scale_factor:.4f}, offset=({g_center.x:.3f}, {g_center.y:.3f}, {g_center.z:.3f}))")

# Also transform Anymate mesh the same way (needed for weight transfer)
bpy.ops.object.select_all(action='DESELECT')
anymate_mesh.select_set(True)
bpy.context.view_layer.objects.active = anymate_mesh
anymate_mesh.location -= a_center
anymate_mesh.scale *= scale_factor
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
anymate_mesh.location = g_center
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Re-parent Anymate mesh to armature
bpy.ops.object.select_all(action='DESELECT')
anymate_mesh.select_set(True)
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm
bpy.ops.object.parent_set(type='ARMATURE')

# --- Create vertex groups on game mesh matching the armature bones ---
for bone in anymate_arm.data.bones:
    if bone.name not in game_mesh.vertex_groups:
        game_mesh.vertex_groups.new(name=bone.name)

# --- Transfer weights from Anymate mesh to game mesh ---
bpy.ops.object.select_all(action='DESELECT')
game_mesh.select_set(True)
bpy.context.view_layer.objects.active = game_mesh

dt = game_mesh.modifiers.new(name="WeightTransfer", type='DATA_TRANSFER')
dt.object = anymate_mesh
dt.use_vert_data = True
dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'POLYINTERP_NEAREST'

bpy.ops.object.datalayout_transfer(modifier=dt.name)
bpy.ops.object.modifier_apply(modifier=dt.name)

weighted = sum(1 for v in game_mesh.data.vertices if len(v.groups) > 0)
total = len(game_mesh.data.vertices)
print(f"Weight transfer: {weighted}/{total} vertices weighted ({weighted/max(total,1)*100:.1f}%)")

# --- Parent game mesh to armature ---
bpy.ops.object.select_all(action='DESELECT')
game_mesh.select_set(True)
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm
bpy.ops.object.parent_set(type='ARMATURE')

# --- Delete Anymate's mesh ---
bpy.ops.object.select_all(action='DESELECT')
anymate_mesh.select_set(True)
bpy.ops.object.delete()

# --- Fix multiple roots ---
bpy.ops.object.select_all(action='DESELECT')
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm
bpy.ops.object.mode_set(mode='EDIT')

roots = [b for b in anymate_arm.data.edit_bones if b.parent is None]
if len(roots) > 1:
    print(f"Fixing {len(roots)} root bones -> adding master root")
    center = Vector((0, 0, 0))
    for r in roots:
        center += r.head
    center /= len(roots)

    master = anymate_arm.data.edit_bones.new("root")
    master.head = center + Vector((0, 0, -0.05))
    master.tail = center
    for r in roots:
        r.parent = master

    bpy.ops.object.mode_set(mode='OBJECT')
    if "root" not in game_mesh.vertex_groups:
        game_mesh.vertex_groups.new(name="root")
    bpy.ops.object.select_all(action='DESELECT')
    anymate_arm.select_set(True)
    bpy.context.view_layer.objects.active = anymate_arm
    bpy.ops.object.mode_set(mode='EDIT')

print(f"Root bones: {len([b for b in anymate_arm.data.edit_bones if b.parent is None])}")

# --- Add snout bone ---
mesh_data = game_mesh.data
wm = game_mesh.matrix_world
mesh_verts = [wm @ v.co for v in mesh_data.vertices]
front_vert = min(mesh_verts, key=lambda v: v.y)

best_bone = None
best_dist = float('inf')
best_point = None
for ebone in anymate_arm.data.edit_bones:
    for pt in [ebone.head, ebone.tail]:
        d = (pt - front_vert).length
        if d < best_dist:
            best_dist = d
            best_bone = ebone
            best_point = Vector(pt)

if best_bone and best_dist >= 0.02:
    direction = (front_vert - best_point).normalized()
    snout = anymate_arm.data.edit_bones.new("snout")
    snout.head = Vector(best_point)
    snout.tail = front_vert + direction * 0.03
    snout.parent = best_bone
    print(f"Added snout bone (parent={best_bone.name})")

    bpy.ops.object.mode_set(mode='OBJECT')

    parent_group = game_mesh.vertex_groups.get(best_bone.name)
    snout_group = game_mesh.vertex_groups.new(name="snout")
    snout_head = Vector(best_point)
    snout_tail = front_vert + direction * 0.03
    snout_center = (snout_head + snout_tail) / 2
    bone_len = (snout_tail - snout_head).length
    radius = max(bone_len * 2.0, 0.06)

    assigned = 0
    for v in mesh_data.vertices:
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
    print(f"Snout weights: {assigned} vertices")
else:
    if best_bone:
        print(f"Snout already covered by {best_bone.name}")
    bpy.ops.object.mode_set(mode='OBJECT')

total_bones = len(anymate_arm.data.bones)
print(f"Final armature: {total_bones} bones")

bpy.ops.export_scene.gltf(filepath=output_glb, export_format='GLB')
print(f"Exported: {output_glb}")
'''


def merge_and_finalize(pet, blend_path, game_glb, output_glb):
    """Run Blender headless to merge armature onto game mesh, fix roots, add snout."""
    script_path = os.path.join(DIR, "_tmp_merge_anymate.py")
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(MERGE_SCRIPT)

    print(f"  [2/4] Merging armature onto game mesh...")
    t0 = time.time()
    r = subprocess.run(
        [BLENDER, "--background", "--python", script_path, "--",
         blend_path, game_glb, output_glb],
        capture_output=True, text=True, timeout=60,
        encoding='utf-8', errors='replace'
    )

    os.remove(script_path)

    for line in r.stdout.split("\n"):
        line = line.strip()
        if line and any(kw in line.lower() for kw in [
            "armature", "mesh", "weight", "root", "snout",
            "final", "exported", "error", "warning", "fix"
        ]):
            print(f"    {line}")

    if r.returncode != 0 and not os.path.exists(output_glb):
        print(f"  [2/4] FAIL (exit code {r.returncode})")
        if r.stderr:
            for line in r.stderr.split("\n")[-5:]:
                if line.strip():
                    print(f"    stderr: {line.strip()}")
        return False

    elapsed = time.time() - t0
    if os.path.exists(output_glb):
        size = os.path.getsize(output_glb) // 1024
        print(f"  [2/4] Done ({elapsed:.1f}s, {size} KB)")
        return True

    print(f"  [2/4] FAIL: output not created")
    return False


# ---------------------------------------------------------------------------
# Step 3: Validate the rig
# ---------------------------------------------------------------------------
def validate_rig(pet, output_glb):
    """Quick validation: check bone count and weight coverage."""
    validate_script = r'''
import bpy, sys, json
argv = sys.argv[sys.argv.index("--") + 1:]
glb_path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

arm = None
mesh = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        arm = obj
    elif obj.type == 'MESH':
        mesh = obj

if arm and mesh:
    total = len(mesh.data.vertices)
    weighted = sum(1 for v in mesh.data.vertices if len(v.groups) > 0)
    roots = sum(1 for b in arm.data.bones if b.parent is None)
    has_snout = any(b.name == 'snout' for b in arm.data.bones)
    print(f"VALIDATE|bones={len(arm.data.bones)}|roots={roots}|verts={total}|weighted={weighted}|coverage={weighted/max(total,1)*100:.1f}|snout={has_snout}")
else:
    print("VALIDATE|ERROR=no armature or mesh")
'''
    script_path = os.path.join(DIR, "_tmp_validate.py")
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(validate_script)

    r = subprocess.run(
        [BLENDER, "--background", "--python", script_path, "--", output_glb],
        capture_output=True, text=True, timeout=30,
        encoding='utf-8', errors='replace'
    )
    os.remove(script_path)

    for line in r.stdout.split("\n"):
        if line.strip().startswith("VALIDATE|"):
            parts = dict(p.split("=") for p in line.strip().split("|")[1:])
            print(f"  [3/4] Validation:")
            print(f"    Bones: {parts.get('bones', '?')}")
            print(f"    Roots: {parts.get('roots', '?')}")
            print(f"    Weight coverage: {parts.get('coverage', '?')}%")
            print(f"    Snout bone: {parts.get('snout', '?')}")
            return "ERROR" not in parts

    print(f"  [3/4] Validation: could not parse output")
    return os.path.exists(output_glb)


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------
def rig_pet(pet):
    game_glb = os.path.join(DIR, f"{pet}-game-340.glb")
    output = os.path.join(DIR, f"{pet}-game-340_rigged.glb")

    if not os.path.exists(game_glb):
        print(f"  ERROR: {pet}-game-340.glb not found")
        return False

    # Remove old rigged file
    if os.path.exists(output):
        os.remove(output)

    # Step 1: Get Anymate rig
    blend_path = anymate_rig(pet, game_glb)
    if not blend_path:
        return False

    # Step 2: Merge + fix roots + add snout
    if not merge_and_finalize(pet, blend_path, game_glb, output):
        return False

    # Step 3: Validate
    validate_rig(pet, output)

    # Step 4: Done
    print(f"  [4/4] Complete: {pet}-game-340_rigged.glb")
    return True


if __name__ == "__main__":
    pets = sys.argv[1:] if len(sys.argv) > 1 else []
    if "--all" in pets:
        pets = ALL_PETS

    if not pets:
        print("Usage: python rig-anymate.py <pet_name> [pet_name2 ...]")
        print("       python rig-anymate.py --all")
        sys.exit(1)

    print(f"Rigging {len(pets)} pets via Anymate: {', '.join(pets)}")
    print(f"Pipeline: Anymate API -> merge armature -> fix roots -> add snout\n")

    results = {}
    for pet in pets:
        print(f"\n{'='*60}")
        print(f"  {pet.upper()}")
        print(f"{'='*60}")
        try:
            ok = rig_pet(pet)
            results[pet] = "OK" if ok else "FAILED"
        except Exception as e:
            print(f"  ERROR: {e}")
            results[pet] = f"ERROR"

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for pet, status in results.items():
        print(f"  {pet}: {status}")
