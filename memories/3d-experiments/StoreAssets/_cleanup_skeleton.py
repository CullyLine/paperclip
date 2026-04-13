"""Clean up Anymate skeleton: remove redundant bones, merge short chains, rename properly.

For a humanoid T-pose character, target ~20 bones:
  hips, spine (2-3), chest, neck, head, head_top,
  upper_arm_L/R, forearm_L/R, hand_L/R,
  upper_leg_L/R, lower_leg_L/R, foot_L/R

Usage: blender --background --python _cleanup_skeleton.py -- <input_rigged.glb> <output.glb>
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

print("=== Skeleton Cleanup ===", flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

armature = None
mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        mesh_obj = obj

verts = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices]
mesh_min = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
mesh_max = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
mesh_center_x = (mesh_min.x + mesh_max.x) / 2
mesh_height = mesh_max.z - mesh_min.z

print(f"Mesh: x=[{mesh_min.x:.3f}, {mesh_max.x:.3f}] z=[{mesh_min.z:.3f}, {mesh_max.z:.3f}]", flush=True)
print(f"Before: {len(armature.data.bones)} bones", flush=True)

bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

ebones = armature.data.edit_bones

MIN_BONE_LENGTH = 0.04

def get_chain(bone):
    chain = [bone]
    current = bone
    while current.children:
        biggest = max(current.children, key=lambda c: c.length)
        chain.append(biggest)
        current = biggest
    return chain

def find_root():
    roots = [b for b in ebones if b.parent is None]
    return roots[0] if roots else None

root = find_root()
if not root:
    print("ERROR: No root bone")
    sys.exit(1)

print(f"\nRoot: {root.name} at z={root.head.z:.3f}", flush=True)

all_bone_data = {}
for eb in ebones:
    all_bone_data[eb.name] = {
        'head': eb.head.copy(),
        'tail': eb.tail.copy(),
        'center': ((eb.head + eb.tail) / 2).copy(),
        'length': eb.length,
        'parent': eb.parent.name if eb.parent else None,
        'children': [c.name for c in eb.children],
        'side': 'R' if eb.head.x > mesh_center_x + 0.05 else ('L' if eb.head.x < mesh_center_x - 0.05 else 'C'),
        'height_pct': (eb.head.z - mesh_min.z) / mesh_height * 100,
    }

spine_chain_names = []
current = root
while current:
    spine_chain_names.append(current.name)
    center_children = [c for c in current.children
                       if abs(c.head.x - mesh_center_x) < 0.08
                       and c.head.z > current.head.z]
    if center_children:
        current = max(center_children, key=lambda c: c.head.z)
    else:
        break

print(f"Spine chain: {len(spine_chain_names)} bones", flush=True)
for name in spine_chain_names:
    d = all_bone_data[name]
    print(f"  {name}: z={d['head'].z:.3f} ({d['height_pct']:.0f}%)", flush=True)

leg_roots = []
arm_roots = []

for name in spine_chain_names:
    eb = ebones[name]
    for child in eb.children:
        if child.name in spine_chain_names:
            continue
        cd = all_bone_data[child.name]
        if cd['head'].z < eb.head.z or cd['height_pct'] < 75:
            leg_roots.append(child)
        elif abs(cd['head'].x - mesh_center_x) > 0.03:
            arm_roots.append(child)
        else:
            arm_roots.append(child)

for name in spine_chain_names:
    eb = ebones[name]
    for child in eb.children:
        if child.name in spine_chain_names:
            continue
        if child in leg_roots or child in arm_roots:
            continue
        cd = all_bone_data[child.name]
        chain = get_chain(child)
        goes_sideways = any(abs(all_bone_data[c.name]['head'].x - mesh_center_x) > 0.15 for c in chain)
        goes_down = any(all_bone_data[c.name]['height_pct'] < 60 for c in chain)
        if goes_down:
            leg_roots.append(child)
        elif goes_sideways:
            arm_roots.append(child)

print(f"\nLeg roots: {[b.name for b in leg_roots]}", flush=True)
print(f"Arm roots: {[b.name for b in arm_roots]}", flush=True)

keep_bones = set(spine_chain_names)
rename_map = {}

def collect_main_chain(root_bone, max_bones=4):
    chain = []
    current = root_bone
    for _ in range(max_bones):
        chain.append(current)
        if not current.children:
            break
        best = max(current.children, key=lambda c: c.length)
        if best.length < 0.015:
            break
        current = best
    return chain

for lr in leg_roots:
    chain = collect_main_chain(lr, max_bones=4)
    side = 'R' if lr.head.x > mesh_center_x + 0.02 else 'L'
    leg_names = [f'upper_leg_{side}', f'lower_leg_{side}', f'foot_{side}', f'toe_{side}']
    
    print(f"\nLeg {side}: {len(chain)} bones kept (from {lr.name})", flush=True)
    for i, bone in enumerate(chain):
        if i < len(leg_names):
            rename_map[bone.name] = leg_names[i]
        keep_bones.add(bone.name)
        print(f"  {bone.name} -> {leg_names[i] if i < len(leg_names) else 'extra'} (z={bone.head.z:.3f}, len={bone.length:.3f})", flush=True)

for ar in arm_roots:
    chain = collect_main_chain(ar, max_bones=4)
    
    avg_x = sum(all_bone_data[c.name]['head'].x for c in chain) / len(chain)
    side = 'R' if avg_x > mesh_center_x + 0.02 else 'L'
    
    any_far = any(abs(all_bone_data[c.name]['head'].x - mesh_center_x) > 0.15 for c in chain)
    if not any_far and len(chain) <= 2:
        print(f"\nSkipping short non-extending arm chain from {ar.name} (not a real arm)", flush=True)
        continue
    
    arm_chain_bones = chain
    arm_names = [f'shoulder_{side}', f'upper_arm_{side}', f'forearm_{side}', f'hand_{side}']
    
    already_have = any(v == f'upper_arm_{side}' for v in rename_map.values())
    if already_have:
        existing_chain_len = sum(1 for v in rename_map.values() if side in v and 'arm' in v.lower())
        if len(chain) <= existing_chain_len:
            print(f"\nSkipping duplicate arm {side} from {ar.name} (already have longer chain)", flush=True)
            continue
        else:
            old_keys = [k for k, v in rename_map.items() if side in v and ('arm' in v.lower() or 'shoulder' in v.lower() or 'hand' in v.lower())]
            for ok in old_keys:
                keep_bones.discard(ok)
                del rename_map[ok]
            print(f"\nReplacing arm {side} with longer chain from {ar.name}", flush=True)
    
    print(f"\nArm {side}: {len(arm_chain_bones)} bones kept (from {ar.name})", flush=True)
    for i, bone in enumerate(arm_chain_bones):
        if i < len(arm_names):
            rename_map[bone.name] = arm_names[i]
        keep_bones.add(bone.name)
        print(f"  {bone.name} -> {arm_names[i] if i < len(arm_names) else 'extra'} (x={bone.head.x:.3f}, len={bone.length:.3f})", flush=True)

spine_labels = ['hips']
remaining_spine = spine_chain_names[1:]

below_neck = [n for n in remaining_spine if all_bone_data[n]['height_pct'] < 83]
at_neck_up = [n for n in remaining_spine if all_bone_data[n]['height_pct'] >= 83]

if len(below_neck) >= 4:
    spine_body = ['spine_lower', 'spine', 'spine_upper', 'chest']
elif len(below_neck) == 3:
    spine_body = ['spine_lower', 'spine', 'chest']
elif len(below_neck) == 2:
    spine_body = ['spine', 'chest']
else:
    spine_body = ['chest'] * len(below_neck)

for i, name in enumerate(below_neck):
    if i < len(spine_body):
        rename_map[name] = spine_body[i]
    else:
        rename_map[name] = f'spine_{i}'

if at_neck_up:
    rename_map[at_neck_up[0]] = 'neck'
    if len(at_neck_up) > 1:
        rename_map[at_neck_up[1]] = 'head'
    for i in range(2, len(at_neck_up)):
        rename_map[at_neck_up[i]] = f'head_top_{i-1}'

rename_map[spine_chain_names[0]] = 'hips'

to_remove = []
for eb in ebones:
    if eb.name not in keep_bones:
        to_remove.append(eb.name)

print(f"\n--- Removing {len(to_remove)} redundant bones ---", flush=True)
for name in to_remove:
    print(f"  REMOVE: {name}", flush=True)

for name in to_remove:
    bone = ebones.get(name)
    if bone:
        for child in list(bone.children):
            if child.name in keep_bones:
                child.parent = bone.parent
        ebones.remove(bone)

print(f"\n--- Renaming {len(rename_map)} bones ---", flush=True)
used = set()
for old_name, new_name in sorted(rename_map.items(), key=lambda x: x[1]):
    bone = ebones.get(old_name)
    if bone:
        final_name = new_name
        if final_name in used:
            final_name = f"{new_name}_2"
        bone.name = final_name
        used.add(final_name)
        print(f"  {old_name} -> {final_name}", flush=True)

bpy.ops.object.mode_set(mode='OBJECT')

for vg in list(mesh_obj.vertex_groups):
    if vg.name in to_remove:
        mesh_obj.vertex_groups.remove(vg)

old_to_new = {}
for old_name, new_name in rename_map.items():
    old_to_new[old_name] = new_name
for vg in mesh_obj.vertex_groups:
    if vg.name in old_to_new:
        vg.name = old_to_new[vg.name]

bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

bone_positions = []
for eb in armature.data.edit_bones:
    bone_positions.append((eb.name, eb.head.copy(), eb.tail.copy()))

bpy.ops.object.mode_set(mode='OBJECT')

for vg in list(mesh_obj.vertex_groups):
    bone = armature.data.bones.get(vg.name)
    if not bone:
        mesh_obj.vertex_groups.remove(vg)

total_verts = len(mesh_obj.data.vertices)
weighted = sum(1 for v in mesh_obj.data.vertices if len(v.groups) > 0)
if weighted < total_verts:
    print(f"\nFixing unweighted vertices: {total_verts - weighted} unweighted", flush=True)
    
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode='EDIT')
    bp = []
    for eb in armature.data.edit_bones:
        bp.append((eb.name, eb.head.copy(), eb.tail.copy()))
    bpy.ops.object.mode_set(mode='OBJECT')
    
    for v in mesh_obj.data.vertices:
        if len(v.groups) == 0:
            v_pos = mesh_obj.matrix_world @ v.co
            best_bone = None
            best_dist = float('inf')
            for bname, bhead, btail in bp:
                mid = (bhead + btail) / 2
                for pt in [bhead, btail, mid]:
                    d = (v_pos - pt).length
                    if d < best_dist:
                        best_dist = d
                        best_bone = bname
            if best_bone:
                vg = mesh_obj.vertex_groups.get(best_bone)
                if not vg:
                    vg = mesh_obj.vertex_groups.new(name=best_bone)
                vg.add([v.index], 1.0, 'REPLACE')
    
    weighted = sum(1 for v in mesh_obj.data.vertices if len(v.groups) > 0)
    print(f"  After fix: {weighted}/{total_verts} ({weighted/max(total_verts,1)*100:.1f}%)", flush=True)

final_bone_count = len(armature.data.bones)
print(f"\n=== RESULT ===", flush=True)
print(f"Bones: {final_bone_count}", flush=True)
print(f"Faces: {len(mesh_obj.data.polygons)}", flush=True)
print(f"Vertices: {total_verts}", flush=True)
print(f"Weight coverage: {weighted}/{total_verts} ({weighted/max(total_verts,1)*100:.1f}%)", flush=True)

print(f"\nFinal bone list:", flush=True)
for bone in sorted(armature.data.bones, key=lambda b: b.name):
    parent = bone.parent.name if bone.parent else "ROOT"
    print(f"  {bone.name} (parent={parent})", flush=True)

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
size_kb = os.path.getsize(output_path) // 1024
print(f"\nExported: {output_path} ({size_kb} KB)", flush=True)
