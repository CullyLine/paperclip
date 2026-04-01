"""Add manual bones to a rigged GLB, preserving existing UniRig weights.

New bones get weights transferred from their parent bone — vertices near the
new bone's head/tail get weight shifted from parent to child.

Usage: blender --background --python add-bones.py -- <rigged.glb> <output.glb> <bones.json>

bones.json format:
[
  {
    "name": "wing_L",
    "head": [x, y, z],
    "tail": [x, y, z],
    "parent": "bone_3"       (optional, auto-finds nearest if omitted)
  },
  ...
]
"""
import bpy
import sys
import json
from mathutils import Vector

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]
bones_json = argv[2]

with open(bones_json, 'r') as f:
    new_bones = json.load(f)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

armature = None
mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        # Pick the mesh that's parented to the armature or has an armature modifier
        has_armature = any(m.type == 'ARMATURE' for m in obj.modifiers)
        if has_armature or obj.parent and obj.parent.type == 'ARMATURE':
            mesh_obj = obj
        elif mesh_obj is None:
            mesh_obj = obj  # fallback to first mesh

if not armature:
    print("ERROR: No armature found!")
    sys.exit(1)

if not mesh_obj:
    print("ERROR: No mesh found!")
    sys.exit(1)

existing_groups = {vg.name for vg in mesh_obj.vertex_groups}
print(f"Armature: {armature.name} ({len(armature.data.bones)} bones)")
print(f"Mesh: {mesh_obj.name} ({len(mesh_obj.data.vertices)} verts, {len(existing_groups)} vertex groups)")
print(f"Adding {len(new_bones)} new bones...\n")

# Enter edit mode on armature to add bones
bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

bone_parent_map = {}

def find_nearest_bone(head_pos):
    target = Vector(head_pos)
    best = None
    best_dist = float('inf')
    for ebone in armature.data.edit_bones:
        for pt in [ebone.head, ebone.tail]:
            dist = (pt - target).length
            if dist < best_dist:
                best_dist = dist
                best = ebone
    return best

for spec in new_bones:
    name = spec["name"]
    head = spec["head"]
    tail = spec["tail"]
    parent_name = spec.get("parent")

    ebone = armature.data.edit_bones.new(name)
    ebone.head = Vector(head)
    ebone.tail = Vector(tail)

    if parent_name and parent_name in armature.data.edit_bones:
        ebone.parent = armature.data.edit_bones[parent_name]
    else:
        nearest = find_nearest_bone(head)
        if nearest:
            ebone.parent = nearest
            parent_name = nearest.name

    bone_parent_map[name] = parent_name or (ebone.parent.name if ebone.parent else None)
    print(f"  Added: {name}  parent={ebone.parent.name if ebone.parent else 'NONE'}")

bpy.ops.object.mode_set(mode='OBJECT')

# Transfer weights from parent bone to new bone for nearby vertices
mesh = mesh_obj.data
world_matrix = mesh_obj.matrix_world

for spec in new_bones:
    name = spec["name"]
    bone_head = Vector(spec["head"])
    bone_tail = Vector(spec["tail"])
    bone_center = (bone_head + bone_tail) / 2
    bone_length = (bone_tail - bone_head).length
    influence_radius = max(bone_length * 1.5, 0.05)

    parent_name = bone_parent_map.get(name)
    parent_group = mesh_obj.vertex_groups.get(parent_name) if parent_name else None

    # Create vertex group for new bone
    new_group = mesh_obj.vertex_groups.new(name=name)

    assigned = 0
    for v in mesh.vertices:
        v_pos = world_matrix @ v.co
        dist = min((v_pos - bone_head).length, (v_pos - bone_tail).length, (v_pos - bone_center).length)

        if dist > influence_radius:
            continue

        # Weight falls off with distance
        weight = max(0.0, 1.0 - (dist / influence_radius))
        weight = weight ** 0.5  # soften falloff

        if parent_group:
            # Steal weight from parent proportionally
            try:
                parent_weight = parent_group.weight(v.index)
            except RuntimeError:
                parent_weight = 0.0

            if parent_weight > 0:
                transfer = parent_weight * weight * 0.6
                new_group.add([v.index], transfer, 'REPLACE')
                parent_group.add([v.index], parent_weight - transfer, 'REPLACE')
                assigned += 1
        else:
            new_group.add([v.index], weight * 0.5, 'REPLACE')
            assigned += 1

    print(f"  Weights: {name} -> {assigned} vertices (radius={influence_radius:.3f})")

total_groups = len(mesh_obj.vertex_groups)
total_bones = len(armature.data.bones)
print(f"\nFinal: {total_bones} bones, {total_groups} vertex groups")

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported: {output_path}")
