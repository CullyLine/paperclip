"""Add a simple procedural armature to a GLB for PetAnimator compatibility.

Creates: root → spine1 → spine2, plus 4 limb chains branching off spine2.
Bone positions are derived from the mesh bounding box.

Usage:
  blender --background --python simple-rig.py -- <input.glb> <output.glb>
"""
import bpy
import sys
import mathutils

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if not meshes:
    print("No mesh objects found")
    sys.exit(1)

target = meshes[0]
for m in meshes:
    if len(m.data.vertices) > len(target.data.vertices):
        target = m

bbox_corners = [target.matrix_world @ mathutils.Vector(c) for c in target.bound_box]
min_x = min(c.x for c in bbox_corners)
max_x = max(c.x for c in bbox_corners)
min_y = min(c.y for c in bbox_corners)
max_y = max(c.y for c in bbox_corners)
min_z = min(c.z for c in bbox_corners)
max_z = max(c.z for c in bbox_corners)

cx = (min_x + max_x) / 2
cy = (min_y + max_y) / 2
cz = (min_z + max_z) / 2
h = max_z - min_z
w = max_x - min_x
d = max_y - min_y

bone_len = h * 0.15
if bone_len < 0.001:
    bone_len = 0.01

arm = bpy.data.armatures.new("PetArmature")
arm_obj = bpy.data.objects.new("PetArmature", arm)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
arm_obj.select_set(True)

bpy.ops.object.mode_set(mode='EDIT')

root = arm.edit_bones.new("Root")
root.head = (cx, cy, min_z)
root.tail = (cx, cy, min_z + bone_len)

spine1 = arm.edit_bones.new("Spine1")
spine1.parent = root
spine1.head = root.tail.copy()
spine1.tail = (cx, cy, cz)

spine2 = arm.edit_bones.new("Spine2")
spine2.parent = spine1
spine2.head = spine1.tail.copy()
spine2.tail = (cx, cy, max_z - bone_len * 0.5)

limb_offsets = [
    ("LimbFrontLeft",  (-w * 0.3, -d * 0.3)),
    ("LimbFrontRight", ( w * 0.3, -d * 0.3)),
    ("LimbBackLeft",   (-w * 0.3,  d * 0.3)),
    ("LimbBackRight",  ( w * 0.3,  d * 0.3)),
]

for name, (ox, oy) in limb_offsets:
    b1 = arm.edit_bones.new(name)
    b1.parent = spine2
    b1.head = spine2.tail.copy()
    b1.tail = (cx + ox, cy + oy, cz)

    tip = arm.edit_bones.new(name + "_tip")
    tip.parent = b1
    tip.head = b1.tail.copy()
    tip.tail = (cx + ox * 1.3, cy + oy * 1.3, min_z)

bpy.ops.object.mode_set(mode='OBJECT')

mod = target.modifiers.new("Armature", 'ARMATURE')
mod.object = arm_obj
target.parent = arm_obj

bpy.ops.object.select_all(action='DESELECT')
target.select_set(True)
bpy.context.view_layer.objects.active = target

for bone in arm.bones:
    vg = target.vertex_groups.get(bone.name)
    if not vg:
        vg = target.vertex_groups.new(name=bone.name)

bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.object.mode_set(mode='OBJECT')

for v in target.data.vertices:
    co = target.matrix_world @ v.co
    best_bone = None
    best_dist = float('inf')
    for bone in arm.bones:
        bone_center = (arm_obj.matrix_world @ bone.head_local + arm_obj.matrix_world @ bone.tail_local) / 2
        dist = (co - bone_center).length
        if dist < best_dist:
            best_dist = dist
            best_bone = bone.name
    if best_bone:
        vg = target.vertex_groups.get(best_bone)
        if vg:
            vg.add([v.index], 1.0, 'REPLACE')

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported rigged model to {output_path}")
bone_count = len(arm.bones)
print(f"Armature has {bone_count} bones")
