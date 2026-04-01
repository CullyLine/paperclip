"""Add a snout bone to a rigged GLB. Finds the frontmost bone and extends it.

Usage: blender --background --python add-snout.py -- <input.glb> <output.glb>
"""
import bpy
import sys
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

mesh = mesh_obj.data
wm = mesh_obj.matrix_world
verts = [wm @ v.co for v in mesh.vertices]

# Front of mesh = most negative Y
front_vert = min(verts, key=lambda v: v.y)
print(f"Mesh front at Y={front_vert.y:.3f}")

# Find bone closest to the front
bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

best_bone = None
best_dist = float('inf')
best_point = None
for ebone in armature.data.edit_bones:
    for pt in [ebone.head, ebone.tail]:
        d = (pt - front_vert).length
        if d < best_dist:
            best_dist = d
            best_bone = ebone
            best_point = Vector(pt)

print(f"Nearest bone to front: {best_bone.name} (dist={best_dist:.3f})")

# Check if snout already covered
if best_dist < 0.02:
    print("Snout already covered, skipping")
    bpy.ops.object.mode_set(mode='OBJECT')
else:
    # Snout extends from the nearest bone point toward (and past) the front of the mesh
    direction = (front_vert - best_point).normalized()
    snout_head = Vector(best_point)
    snout_tail = front_vert + direction * 0.03

    snout = armature.data.edit_bones.new("snout")
    snout.head = snout_head
    snout.tail = snout_tail
    snout.parent = best_bone
    print(f"Added snout: head=({snout_head.x:.3f},{snout_head.y:.3f},{snout_head.z:.3f}) "
          f"tail=({snout_tail.x:.3f},{snout_tail.y:.3f},{snout_tail.z:.3f}) "
          f"parent={best_bone.name}")

    bpy.ops.object.mode_set(mode='OBJECT')

    # Transfer weights
    parent_group = mesh_obj.vertex_groups.get(best_bone.name)
    snout_group = mesh_obj.vertex_groups.new(name="snout")

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

    print(f"Snout weights: {assigned} vertices (radius={radius:.3f})")

total = len(armature.data.bones)
print(f"Final: {total} bones")

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported: {output_path}")
