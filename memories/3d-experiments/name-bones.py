"""Auto-rename bones based on spatial position in the skeleton.

Analyzes bone head/tail positions relative to the mesh bounding box
to assign meaningful names (spine, head, arm_L, arm_R, leg_L, leg_R, etc.).

Usage: blender --background --python name-bones.py -- <input_rigged.glb> <output.glb>
"""
import bpy
import sys
from mathutils import Vector

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

armature = None
mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        mesh_obj = obj

if not armature:
    print("ERROR: No armature found")
    sys.exit(1)

bones = armature.data.bones
bone_count = len(bones)
print(f"Armature: {armature.name} ({bone_count} bones)")

verts = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices] if mesh_obj else []
if verts:
    mesh_min = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    mesh_max = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    mesh_center_x = (mesh_min.x + mesh_max.x) / 2
    mesh_height = mesh_max.z - mesh_min.z
    mesh_center_z = (mesh_min.z + mesh_max.z) / 2
    print(f"Mesh bounds: x=[{mesh_min.x:.3f}, {mesh_max.x:.3f}] z=[{mesh_min.z:.3f}, {mesh_max.z:.3f}]")
    print(f"Mesh center X: {mesh_center_x:.3f}, height: {mesh_height:.3f}")

bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

ebones = armature.data.edit_bones

bone_info = []
for eb in ebones:
    center = (eb.head + eb.tail) / 2
    bone_info.append({
        'name': eb.name,
        'bone': eb,
        'head': eb.head.copy(),
        'tail': eb.tail.copy(),
        'center': center,
        'length': eb.length,
        'parent': eb.parent.name if eb.parent else None,
        'children': [c.name for c in eb.children],
        'depth': 0,
    })

def calc_depth(info_list):
    name_to_info = {b['name']: b for b in info_list}
    for b in info_list:
        depth = 0
        current = b
        while current['parent']:
            depth += 1
            current = name_to_info.get(current['parent'], {'parent': None})
        b['depth'] = depth

calc_depth(bone_info)

X_THRESHOLD = 0.03

def side_label(x):
    if x > mesh_center_x + X_THRESHOLD:
        return "_R"
    elif x < mesh_center_x - X_THRESHOLD:
        return "_L"
    return ""

root_bones = [b for b in bone_info if b['parent'] is None]
root = root_bones[0] if root_bones else None

rename_map = {}
used_names = set()

def unique_name(base):
    if base not in used_names:
        used_names.add(base)
        return base
    i = 2
    while f"{base}_{i}" in used_names:
        i += 1
    name = f"{base}_{i}"
    used_names.add(name)
    return name

name_to_info = {b['name']: b for b in bone_info}

spine_chain = []
if root:
    current = root
    while current:
        spine_chain.append(current['name'])
        center_children = [
            name_to_info[c] for c in current['children']
            if abs(name_to_info[c]['center'].x - mesh_center_x) < X_THRESHOLD * 3
        ]
        if center_children:
            current = max(center_children, key=lambda b: b['center'].z)
        else:
            break

spine_names = ['hips', 'spine_lower', 'spine', 'spine_upper', 'chest', 'neck', 'head']

for i, bone_name in enumerate(spine_chain):
    if i < len(spine_names):
        new_name = spine_names[i]
    else:
        new_name = f"spine_{i}"
    rename_map[bone_name] = unique_name(new_name)

def classify_branch(start_name, start_info):
    """Classify a branch coming off the spine."""
    cx = start_info['center'].x
    cz = start_info['center'].z

    side = side_label(cx)

    height_ratio = (cz - mesh_min.z) / max(mesh_height, 0.001)

    chain = []
    current = start_info
    while current:
        chain.append(current['name'])
        if current['children']:
            child_infos = [name_to_info[c] for c in current['children'] if c not in spine_chain]
            if child_infos:
                current = child_infos[0]
            else:
                break
        else:
            break

    if height_ratio > 0.55:
        base_names = ['shoulder', 'upper_arm', 'forearm', 'hand', 'finger_1', 'finger_2', 'finger_3']
    elif height_ratio < 0.35:
        base_names = ['upper_leg', 'lower_leg', 'foot', 'toe', 'toe_tip']
    else:
        base_names = ['limb_1', 'limb_2', 'limb_3', 'limb_4', 'limb_5']

    for i, bone_name in enumerate(chain):
        if bone_name in rename_map:
            continue
        if i < len(base_names):
            new_name = f"{base_names[i]}{side}"
        else:
            new_name = f"extra_{i}{side}"
        rename_map[bone_name] = unique_name(new_name)

for bone_name in spine_chain:
    info = name_to_info[bone_name]
    for child_name in info['children']:
        if child_name in spine_chain:
            continue
        child_info = name_to_info[child_name]
        classify_branch(child_name, child_info)

for b in bone_info:
    if b['name'] not in rename_map and b['name'] != 'snout':
        side = side_label(b['center'].x)
        height_ratio = (b['center'].z - mesh_min.z) / max(mesh_height, 0.001)
        if height_ratio > 0.7:
            base = f"head_extra{side}"
        elif height_ratio > 0.4:
            base = f"torso_extra{side}"
        else:
            base = f"leg_extra{side}"
        rename_map[b['name']] = unique_name(base)

rename_map['snout'] = 'snout'

print(f"\nRenaming {len(rename_map)} bones:")
for old, new in sorted(rename_map.items(), key=lambda x: x[1]):
    print(f"  {old:>10} -> {new}")

for eb in ebones:
    if eb.name in rename_map:
        eb.name = rename_map[eb.name]

bpy.ops.object.mode_set(mode='OBJECT')

import os as _os
bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
size_kb = _os.path.getsize(output_path) // 1024
print(f"\nExported with named bones: {output_path} ({size_kb} KB)")
