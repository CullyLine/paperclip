"""Build a clean humanoid skeleton from scratch for a T-pose mesh.

Analyzes mesh geometry to place bones at correct positions:
  hips → spine → chest → neck → head
  hips → upper_leg_L/R → lower_leg_L/R → foot_L/R
  chest → upper_arm_L/R → forearm_L/R → hand_L/R

Usage: blender --background --python _build_clean_skeleton.py -- <input.glb> <output.glb>
"""
import bpy
import sys
import os
from mathutils import Vector

sys.stdout.reconfigure(line_buffering=True)

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]

print("=== Build Clean Skeleton ===", flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        mesh_obj = obj
        break

for obj in list(bpy.context.scene.objects):
    if obj.type == 'ARMATURE':
        bpy.data.objects.remove(obj, do_unlink=True)

verts = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices]
xs = [v.x for v in verts]
ys = [v.y for v in verts]
zs = [v.z for v in verts]

mesh_min = Vector((min(xs), min(ys), min(zs)))
mesh_max = Vector((max(xs), max(ys), max(zs)))
cx = (mesh_min.x + mesh_max.x) / 2
height = mesh_max.z - mesh_min.z
width = mesh_max.x - mesh_min.x

print(f"Mesh bounds: x=[{mesh_min.x:.3f}, {mesh_max.x:.3f}] y=[{mesh_min.y:.3f}, {mesh_max.y:.3f}] z=[{mesh_min.z:.3f}, {mesh_max.z:.3f}]", flush=True)
print(f"Height: {height:.3f}, Width: {width:.3f}", flush=True)
print(f"Faces: {len(mesh_obj.data.polygons)}, Verts: {len(mesh_obj.data.vertices)}", flush=True)

body_width_threshold = width * 0.35

z_slices = {}
for v in verts:
    z_bucket = round(v.z, 2)
    if z_bucket not in z_slices:
        z_slices[z_bucket] = []
    z_slices[z_bucket].append(v.x)

arm_z = None
arm_z_candidates = []
for z_val in sorted(z_slices.keys()):
    xs = z_slices[z_val]
    slice_width = max(xs) - min(xs)
    if slice_width > body_width_threshold and z_val > mesh_min.z + height * 0.3:
        arm_z_candidates.append(z_val)

if arm_z_candidates:
    arm_z = sum(arm_z_candidates) / len(arm_z_candidates)
    print(f"  Arm Z detected from {len(arm_z_candidates)} wide slices, range [{arm_z_candidates[0]:.3f}, {arm_z_candidates[-1]:.3f}]", flush=True)
else:
    arm_z = mesh_min.z + height * 0.55
    print(f"  Arm Z fallback: {arm_z:.3f}", flush=True)

left_arm_verts = [v for v in verts if v.x < cx - 0.15 and abs(v.z - arm_z) < height * 0.1]
right_arm_verts = [v for v in verts if v.x > cx + 0.15 and abs(v.z - arm_z) < height * 0.1]

left_tip_x = min(v.x for v in left_arm_verts) if left_arm_verts else mesh_min.x
right_tip_x = max(v.x for v in right_arm_verts) if right_arm_verts else mesh_max.x

body_min_x = cx - 0.08
body_max_x = cx + 0.08

leg_verts = [v for v in verts if v.z < mesh_min.z + height * 0.35 and body_min_x < v.x < body_max_x]
leg_split_z = mesh_min.z + height * 0.30 if leg_verts else mesh_min.z + height * 0.25

left_leg_verts = [v for v in verts if v.z < leg_split_z and v.x < cx]
right_leg_verts = [v for v in verts if v.z < leg_split_z and v.x > cx]

left_leg_x = sum(v.x for v in left_leg_verts) / max(len(left_leg_verts), 1) if left_leg_verts else cx - 0.05
right_leg_x = sum(v.x for v in right_leg_verts) / max(len(right_leg_verts), 1) if right_leg_verts else cx + 0.05

cy_body = sum(v.y for v in verts) / len(verts)

print(f"\nLandmarks:", flush=True)
print(f"  Arm Z: {arm_z:.3f}", flush=True)
print(f"  Left arm tip X: {left_tip_x:.3f}", flush=True)
print(f"  Right arm tip X: {right_tip_x:.3f}", flush=True)
print(f"  Left leg X: {left_leg_x:.3f}", flush=True)
print(f"  Right leg X: {right_leg_x:.3f}", flush=True)
print(f"  Body center Y: {cy_body:.3f}", flush=True)

hips_z = mesh_min.z + height * 0.32
spine_z = mesh_min.z + height * 0.45
chest_z = mesh_min.z + height * 0.58
neck_z = mesh_min.z + height * 0.70
head_base_z = mesh_min.z + height * 0.75
head_top_z = mesh_max.z

knee_z = mesh_min.z + height * 0.15
ankle_z = mesh_min.z + height * 0.04
toe_z = mesh_min.z

torso_verts_at_arm_z = [v for v in verts
                         if abs(v.z - arm_z) < height * 0.05
                         and abs(v.x - cx) < width * 0.25]
if torso_verts_at_arm_z:
    torso_half_width = max(abs(v.x - cx) for v in torso_verts_at_arm_z)
    shoulder_offset = torso_half_width * 0.9
else:
    shoulder_offset = 0.10
print(f"  Torso half-width at arm Z: {torso_half_width:.3f}, shoulder offset: {shoulder_offset:.3f}", flush=True)

elbow_x_L = left_tip_x * 0.45 + (cx - shoulder_offset) * 0.55
elbow_x_R = right_tip_x * 0.45 + (cx + shoulder_offset) * 0.55
wrist_x_L = left_tip_x * 0.75 + (cx - shoulder_offset) * 0.25
wrist_x_R = right_tip_x * 0.75 + (cx + shoulder_offset) * 0.25

print(f"\nBone positions:", flush=True)
print(f"  Hips Z: {hips_z:.3f}", flush=True)
print(f"  Chest Z: {chest_z:.3f}", flush=True)
print(f"  Neck Z: {neck_z:.3f}", flush=True)
print(f"  Head top Z: {head_top_z:.3f}", flush=True)

arm_data = bpy.data.armatures.new("Skeleton")
arm_obj = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='EDIT')
ebones = arm_data.edit_bones

def add_bone(name, head, tail, parent_name=None):
    b = ebones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if parent_name:
        b.parent = ebones[parent_name]
    print(f"  + {name}: ({head[0]:.3f}, {head[1]:.3f}, {head[2]:.3f}) -> ({tail[0]:.3f}, {tail[1]:.3f}, {tail[2]:.3f})", flush=True)
    return b

print("\nCreating bones:", flush=True)

add_bone("hips", (cx, cy_body, hips_z), (cx, cy_body, spine_z))
add_bone("spine", (cx, cy_body, spine_z), (cx, cy_body, chest_z), "hips")
add_bone("chest", (cx, cy_body, chest_z), (cx, cy_body, neck_z), "spine")
add_bone("neck", (cx, cy_body, neck_z), (cx, cy_body, head_base_z), "chest")
add_bone("head", (cx, cy_body, head_base_z), (cx, cy_body, head_top_z), "neck")

add_bone("upper_arm_L",
         (cx - shoulder_offset, cy_body, arm_z),
         (elbow_x_L, cy_body, arm_z), "chest")
add_bone("forearm_L",
         (elbow_x_L, cy_body, arm_z),
         (wrist_x_L, cy_body, arm_z), "upper_arm_L")
add_bone("hand_L",
         (wrist_x_L, cy_body, arm_z),
         (left_tip_x, cy_body, arm_z), "forearm_L")

add_bone("upper_arm_R",
         (cx + shoulder_offset, cy_body, arm_z),
         (elbow_x_R, cy_body, arm_z), "chest")
add_bone("forearm_R",
         (elbow_x_R, cy_body, arm_z),
         (wrist_x_R, cy_body, arm_z), "upper_arm_R")
add_bone("hand_R",
         (wrist_x_R, cy_body, arm_z),
         (right_tip_x, cy_body, arm_z), "forearm_R")

add_bone("upper_leg_L",
         (left_leg_x, cy_body, hips_z),
         (left_leg_x, cy_body, knee_z), "hips")
add_bone("lower_leg_L",
         (left_leg_x, cy_body, knee_z),
         (left_leg_x, cy_body, ankle_z), "upper_leg_L")
add_bone("foot_L",
         (left_leg_x, cy_body, ankle_z),
         (left_leg_x, cy_body - 0.06, toe_z), "lower_leg_L")

add_bone("upper_leg_R",
         (right_leg_x, cy_body, hips_z),
         (right_leg_x, cy_body, knee_z), "hips")
add_bone("lower_leg_R",
         (right_leg_x, cy_body, knee_z),
         (right_leg_x, cy_body, ankle_z), "upper_leg_R")
add_bone("foot_R",
         (right_leg_x, cy_body, ankle_z),
         (right_leg_x, cy_body - 0.06, toe_z), "lower_leg_R")

bpy.ops.object.mode_set(mode='OBJECT')

print(f"\nCreated {len(arm_data.bones)} bones", flush=True)

mesh_obj.parent = arm_obj
mod = mesh_obj.modifiers.new(name='Armature', type='ARMATURE')
mod.object = arm_obj

bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='EDIT')
bone_positions = []
for eb in arm_data.edit_bones:
    bone_positions.append((eb.name, eb.head.copy(), eb.tail.copy()))
bpy.ops.object.mode_set(mode='OBJECT')

for bname, _, _ in bone_positions:
    mesh_obj.vertex_groups.new(name=bname)

left_bones = {n for n, _, _ in bone_positions if n.endswith('_L')}
right_bones = {n for n, _, _ in bone_positions if n.endswith('_R')}
center_bones = {n for n, _, _ in bone_positions if not n.endswith('_L') and not n.endswith('_R')}

SIDE_MARGIN = 0.02

print("\nAssigning vertex weights (isolated sides, sharp falloff)...", flush=True)
for v in mesh_obj.data.vertices:
    v_pos = mesh_obj.matrix_world @ v.co

    if v_pos.x < cx - SIDE_MARGIN:
        v_side = 'L'
    elif v_pos.x > cx + SIDE_MARGIN:
        v_side = 'R'
    else:
        v_side = 'C'

    distances = []
    for bname, bhead, btail in bone_positions:
        if v_side == 'L' and bname in right_bones:
            continue
        if v_side == 'R' and bname in left_bones:
            continue

        bone_dir = btail - bhead
        bone_len = bone_dir.length
        if bone_len > 0.001:
            t = max(0, min(1, (v_pos - bhead).dot(bone_dir) / (bone_len * bone_len)))
            closest = bhead + bone_dir * t
        else:
            closest = (bhead + btail) / 2
        d = (v_pos - closest).length
        distances.append((bname, d))

    distances.sort(key=lambda x: x[1])

    top_bones = distances[:2]

    weights = []
    for bname, d in top_bones:
        w = 1.0 / max(d, 0.0001) ** 3
        weights.append((bname, w))

    total_w = sum(w for _, w in weights)
    for bname, w in weights:
        normalized = w / total_w
        if normalized > 0.15:
            vg = mesh_obj.vertex_groups[bname]
            vg.add([v.index], normalized, 'REPLACE')

total = len(mesh_obj.data.vertices)
weighted = sum(1 for v in mesh_obj.data.vertices if len(v.groups) > 0)
print(f"Weight coverage: {weighted}/{total} ({weighted/max(total,1)*100:.1f}%)", flush=True)

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
size_kb = os.path.getsize(output_path) // 1024

print(f"\n=== RESULT ===", flush=True)
print(f"Bones: {len(arm_data.bones)}", flush=True)
print(f"Faces: {len(mesh_obj.data.polygons)}", flush=True)
print(f"Vertices: {total}", flush=True)
print(f"File: {output_path} ({size_kb} KB)", flush=True)
print(f"\nBone hierarchy:", flush=True)
for bone in arm_data.bones:
    parent = bone.parent.name if bone.parent else "ROOT"
    print(f"  {bone.name} <- {parent}", flush=True)
