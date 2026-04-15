"""Rotate forearm and hand vertices 180° so palms face down (standard T-pose).

Flips vertices around the arm axis on both sides. Updates both the base
rigged GLB and exports a mesh-only FBX for Mixamo upload.

Usage:
  blender --background --python _fix_palm_orientation.py -- <input.glb> <output.glb> <output_meshonly.fbx>
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
input_glb = args[0]
output_glb = args[1]
output_fbx = args[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)

mesh_obj = None
arm_obj = None
for obj in bpy.data.objects:
    if obj.type == "MESH" and obj.name != "Icosphere":
        mesh_obj = obj
    elif obj.type == "ARMATURE":
        arm_obj = obj

for obj in list(bpy.data.objects):
    if obj.name == "Icosphere":
        bpy.data.objects.remove(obj, do_unlink=True)

verts = mesh_obj.data.vertices
world = mesh_obj.matrix_world

all_coords = [world @ v.co for v in verts]
xs = [c.x for c in all_coords]
zs = [c.z for c in all_coords]
cx = (min(xs) + max(xs)) / 2
height = max(zs) - min(zs)

arm_z = min(zs) + height * 0.58
cy = sum(c.y for c in all_coords) / len(all_coords)

# Threshold: vertices beyond this X distance from center are forearm/hand
forearm_threshold = 0.30

inv_world = world.inverted()

left_count = 0
right_count = 0

for v in verts:
    world_co = world @ v.co

    # Left arm (negative X)
    if world_co.x < cx - forearm_threshold and abs(world_co.z - arm_z) < height * 0.12:
        # Rotate 180° around the arm axis (parallel to X at cy, arm_z)
        new_y = 2 * cy - world_co.y
        new_z = 2 * arm_z - world_co.z
        new_world = Vector((world_co.x, new_y, new_z))
        v.co = inv_world @ new_world
        left_count += 1

    # Right arm (positive X)
    elif world_co.x > cx + forearm_threshold and abs(world_co.z - arm_z) < height * 0.12:
        new_y = 2 * cy - world_co.y
        new_z = 2 * arm_z - world_co.z
        new_world = Vector((world_co.x, new_y, new_z))
        v.co = inv_world @ new_world
        right_count += 1

print(f"Flipped {left_count} left arm verts, {right_count} right arm verts", flush=True)
print(f"Arm axis: y={cy:.3f}, z={arm_z:.3f}", flush=True)

# Export base model with armature
bpy.ops.export_scene.gltf(filepath=output_glb, export_format='GLB')
print(f"GLB: {output_glb} ({os.path.getsize(output_glb)//1024} KB)", flush=True)

# Now export mesh-only FBX for Mixamo
if arm_obj:
    bpy.data.objects.remove(arm_obj, do_unlink=True)
mesh_obj.vertex_groups.clear()
for mod in list(mesh_obj.modifiers):
    if mod.type == 'ARMATURE':
        mesh_obj.modifiers.remove(mod)
mesh_obj.parent = None

# 180° rotation for FBX
mesh_obj.rotation_euler[2] = math.pi
bpy.context.view_layer.objects.active = mesh_obj
mesh_obj.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

bpy.ops.export_scene.fbx(filepath=output_fbx, apply_scale_options='FBX_SCALE_ALL')
print(f"FBX: {output_fbx} ({os.path.getsize(output_fbx)//1024} KB)", flush=True)
print("Done!", flush=True)
