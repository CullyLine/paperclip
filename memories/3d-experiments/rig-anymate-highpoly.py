"""Rig via Anymate using HIGHPOLY model for better bone precision.

Sends the highpoly GLB to Anymate (richer geometry = better skeleton),
then merges the resulting armature onto the lowpoly game model.

Usage:
  python rig-anymate-highpoly.py <name> <highpoly.glb> <lowpoly.glb> <output.glb>

Example:
  python rig-anymate-highpoly.py StoreTungTung \
    StoreAssets/StoreTungTung-highpoly.glb \
    StoreAssets/StoreTungTung-game-500.glb \
    StoreAssets/StoreTungTung-game-500_rigged.glb
"""
import os, sys, subprocess, shutil, time

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

BLENDER = r"F:\SteamLibrary\steamapps\common\Blender\blender.exe"
DIR = os.path.dirname(os.path.abspath(__file__))

name = sys.argv[1] if len(sys.argv) > 1 else None
highpoly_glb = sys.argv[2] if len(sys.argv) > 2 else None
lowpoly_glb = sys.argv[3] if len(sys.argv) > 3 else None
output_glb = sys.argv[4] if len(sys.argv) > 4 else None

if not all([name, highpoly_glb, lowpoly_glb, output_glb]):
    print("Usage: python rig-anymate-highpoly.py <name> <highpoly.glb> <lowpoly.glb> <output.glb>")
    sys.exit(1)

highpoly_glb = os.path.abspath(highpoly_glb)
lowpoly_glb = os.path.abspath(lowpoly_glb)
output_glb = os.path.abspath(output_glb)
out_dir = os.path.dirname(output_glb)

print(f"{'='*60}")
print(f"  HIGHPOLY ANYMATE RIG: {name}")
print(f"{'='*60}")
print(f"  Highpoly: {os.path.basename(highpoly_glb)}")
print(f"  Lowpoly:  {os.path.basename(lowpoly_glb)}")
print(f"  Output:   {os.path.basename(output_glb)}")
print()


# Step 1: Submit HIGHPOLY to Anymate
blend_out = os.path.join(out_dir, f"{name}-anymate-hp.blend")

if os.path.exists(blend_out):
    print(f"  [1/4] Using cached {name}-anymate-hp.blend")
else:
    print(f"  [1/4] Submitting HIGHPOLY to Anymate API...")
    t0 = time.time()

    from gradio_client import Client, handle_file
    hf_token = os.environ.get("HF_TOKEN")
    client = Client("yfdeng/Anymate", token=hf_token)

    client.predict(mesh_file=handle_file(highpoly_glb), api_name="/process_input")
    client.predict(eps=0.03, min_samples=1, api_name="/get_all_results")
    client.predict(api_name="/vis_all")
    blend_result = client.predict(api_name="/prepare_blender_file")

    elapsed = time.time() - t0

    if blend_result and os.path.exists(blend_result):
        shutil.copy2(blend_result, blend_out)
        print(f"  [1/4] Done ({elapsed:.1f}s) -> {name}-anymate-hp.blend")
    else:
        print(f"  [1/4] FAIL: Anymate returned no .blend")
        sys.exit(1)


# Step 2: Merge Anymate armature onto LOWPOLY game mesh
MERGE_SCRIPT = r'''
import bpy, sys, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
blend_path, game_glb, output_glb = argv[0], argv[1], argv[2]


def get_bbox(obj):
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

bpy.ops.import_scene.gltf(filepath=game_glb)

game_mesh = None
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj != anymate_mesh:
        game_mesh = obj

if not game_mesh:
    print("ERROR: Could not find game mesh after import")
    sys.exit(1)

print(f"    Anymate armature: {anymate_arm.name} ({len(anymate_arm.data.bones)} bones)")
if anymate_mesh:
    print(f"    Anymate mesh: {anymate_mesh.name} ({len(anymate_mesh.data.vertices)} verts)")
print(f"    Game mesh: {game_mesh.name} ({len(game_mesh.data.vertices)} verts)")

# Align armature to game mesh
if anymate_mesh:
    a_center, a_size, _, _ = get_bbox(anymate_mesh)
else:
    a_center, a_size, _, _ = get_bbox(anymate_arm)
g_center, g_size, _, _ = get_bbox(game_mesh)

scale_factors = []
for i in range(3):
    if a_size[i] > 0.001:
        scale_factors.append(g_size[i] / a_size[i])
scale = sum(scale_factors) / len(scale_factors) if scale_factors else 1.0

anymate_arm.scale = (scale, scale, scale)
bpy.context.view_layer.update()

if anymate_mesh:
    a_center2, _, _, _ = get_bbox(anymate_mesh)
else:
    a_center2 = anymate_arm.location * scale
offset = g_center - a_center2
anymate_arm.location += offset
bpy.context.view_layer.update()

print(f"    Armature aligned to game mesh (scale={scale:.4f}, offset=({offset.x:.3f}, {offset.y:.3f}, {offset.z:.3f}))")

# Apply armature transforms
bpy.ops.object.select_all(action='DESELECT')
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Parent game mesh to armature
game_mesh.parent = anymate_arm
mod = game_mesh.modifiers.new(name='Armature', type='ARMATURE')
mod.object = anymate_arm

# Transfer weights from Anymate mesh to game mesh
if anymate_mesh:
    for vg in anymate_mesh.vertex_groups:
        if vg.name not in game_mesh.vertex_groups:
            game_mesh.vertex_groups.new(name=vg.name)

    bpy.ops.object.select_all(action='DESELECT')
    anymate_mesh.select_set(True)
    game_mesh.select_set(True)
    bpy.context.view_layer.objects.active = game_mesh

    try:
        bpy.ops.object.data_transfer(
            use_reverse_transfer=True,
            data_type='VGROUP_WEIGHTS',
            vert_mapping='NEAREST',
            layers_select_src='ALL',
            layers_select_dst='NAME'
        )
    except:
        pass

    total = len(game_mesh.data.vertices)
    weighted = sum(1 for v in game_mesh.data.vertices if len(v.groups) > 0)
    if weighted < total * 0.5:
        print(f"    Data transfer low ({weighted}/{total}), using proximity fallback...")
        bone_data = []
        bpy.ops.object.select_all(action='DESELECT')
        anymate_arm.select_set(True)
        bpy.context.view_layer.objects.active = anymate_arm
        bpy.ops.object.mode_set(mode='EDIT')
        for ebone in anymate_arm.data.edit_bones:
            bone_data.append((ebone.name, ebone.head.copy(), ebone.tail.copy()))
        bpy.ops.object.mode_set(mode='OBJECT')

        for v in game_mesh.data.vertices:
            if len(v.groups) > 0:
                continue
            v_pos = game_mesh.matrix_world @ v.co
            best_bone = None
            best_dist = float('inf')
            for bname, bhead, btail in bone_data:
                for pt in [bhead, btail, (bhead + btail) / 2]:
                    d = (v_pos - pt).length
                    if d < best_dist:
                        best_dist = d
                        best_bone = bname
            if best_bone:
                vg = game_mesh.vertex_groups.get(best_bone)
                if not vg:
                    vg = game_mesh.vertex_groups.new(name=best_bone)
                vg.add([v.index], 1.0, 'REPLACE')

    total = len(game_mesh.data.vertices)
    weighted = sum(1 for v in game_mesh.data.vertices if len(v.groups) > 0)
    print(f"    Weight transfer: {weighted}/{total} vertices weighted ({weighted/max(total,1)*100:.1f}%)")

# Fix root bones
bpy.ops.object.select_all(action='DESELECT')
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm
bpy.ops.object.mode_set(mode='EDIT')

roots = [b for b in anymate_arm.data.edit_bones if b.parent is None]
if len(roots) > 1:
    main_root = max(roots, key=lambda b: len(b.children_recursive))
    for r in roots:
        if r != main_root:
            r.parent = main_root
    print(f"    Root bones: {len(roots)} -> 1 (merged under {main_root.name})")
else:
    print(f"    Root bones: 1")

bpy.ops.object.mode_set(mode='OBJECT')

# Add snout bone
bone_data_final = []
bpy.ops.object.select_all(action='DESELECT')
anymate_arm.select_set(True)
bpy.context.view_layer.objects.active = anymate_arm
bpy.ops.object.mode_set(mode='EDIT')

for ebone in anymate_arm.data.edit_bones:
    bone_data_final.append((ebone.name, ebone.head.copy(), ebone.tail.copy()))

if bone_data_final:
    front_bone = min(bone_data_final, key=lambda b: b[1].y)
    parent_ebone = anymate_arm.data.edit_bones[front_bone[0]]
    snout = anymate_arm.data.edit_bones.new('snout')
    snout.head = parent_ebone.tail.copy()
    direction = parent_ebone.tail - parent_ebone.head
    snout.tail = snout.head + direction
    snout.parent = parent_ebone
    print(f"    Added snout bone (parent={front_bone[0]})")

    bpy.ops.object.mode_set(mode='OBJECT')

    snout_vg = game_mesh.vertex_groups.new(name='snout')
    snout_head = snout.head if hasattr(snout, 'head') else Vector((0,0,0))
    snout_tail = snout.tail if hasattr(snout, 'tail') else Vector((0,0,0))

    bpy.ops.object.select_all(action='DESELECT')
    anymate_arm.select_set(True)
    bpy.context.view_layer.objects.active = anymate_arm
    bpy.ops.object.mode_set(mode='EDIT')
    snout_ebone = anymate_arm.data.edit_bones.get('snout')
    if snout_ebone:
        snout_head = snout_ebone.head.copy()
        snout_tail = snout_ebone.tail.copy()
    bpy.ops.object.mode_set(mode='OBJECT')

    snout_center = (snout_head + snout_tail) / 2
    radius = max((snout_tail - snout_head).length * 2.0, 0.1)
    assigned = 0
    for v in game_mesh.data.vertices:
        v_pos = game_mesh.matrix_world @ v.co
        dist = min((v_pos - snout_head).length, (v_pos - snout_tail).length, (v_pos - snout_center).length)
        if dist < radius:
            weight = max(0.0, 1.0 - (dist / radius)) ** 0.5
            snout_vg.add([v.index], weight * 0.5, 'ADD')
            assigned += 1
    print(f"    Snout weights: {assigned} vertices")
else:
    bpy.ops.object.mode_set(mode='OBJECT')

# Count final bones
final_bones = len(anymate_arm.data.bones)
print(f"    Final armature: {final_bones} bones")

# Delete Anymate mesh, keep only game mesh + armature
if anymate_mesh:
    bpy.data.objects.remove(anymate_mesh, do_unlink=True)

bpy.ops.export_scene.gltf(filepath=output_glb, export_format='GLB')
size_kb = os.path.getsize(output_glb) // 1024
print(f"    Exported: {output_glb}")
'''

print(f"  [2/4] Merging HIGHPOLY armature onto LOWPOLY game mesh...")
merge_script_path = os.path.join(out_dir, "_tmp_merge_hp.py")
with open(merge_script_path, 'w', encoding='utf-8') as f:
    f.write(MERGE_SCRIPT)

t0 = time.time()
r = subprocess.run(
    [BLENDER, "--background", "--python", merge_script_path, "--",
     blend_out, lowpoly_glb, output_glb],
    capture_output=True, text=True, timeout=120,
    encoding='utf-8', errors='replace'
)
elapsed = time.time() - t0

for line in r.stdout.split("\n"):
    line = line.strip()
    if line.startswith(("    ", "  [", "ERROR")):
        print(line)

os.remove(merge_script_path)

if not os.path.exists(output_glb):
    print(f"  [2/4] FAILED ({elapsed:.1f}s)")
    print(f"  STDERR: {r.stderr[-500:]}")
    sys.exit(1)

size_kb = os.path.getsize(output_glb) // 1024
print(f"  [2/4] Done ({elapsed:.1f}s, {size_kb} KB)")


# Step 3: Validate
print(f"  [3/4] Validating...")
VALIDATE_SCRIPT = r'''
import bpy, sys
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
val_path = os.path.join(out_dir, "_tmp_validate_hp.py")
with open(val_path, 'w', encoding='utf-8') as f:
    f.write(VALIDATE_SCRIPT)

r = subprocess.run(
    [BLENDER, "--background", "--python", val_path, "--", output_glb],
    capture_output=True, text=True, timeout=30,
    encoding='utf-8', errors='replace'
)
os.remove(val_path)

for line in r.stdout.split("\n"):
    if line.strip().startswith("VALIDATE|"):
        parts = dict(p.split("=") for p in line.strip().split("|")[1:])
        print(f"    Bones: {parts.get('bones', '?')}")
        print(f"    Roots: {parts.get('roots', '?')}")
        print(f"    Vertices: {parts.get('verts', '?')}")
        print(f"    Weight coverage: {parts.get('coverage', '?')}%")
        print(f"    Snout bone: {parts.get('snout', '?')}")

print(f"  [4/4] Complete: {os.path.basename(output_glb)}")
print(f"\n{'='*60}")
print("DONE")
print(f"{'='*60}")
