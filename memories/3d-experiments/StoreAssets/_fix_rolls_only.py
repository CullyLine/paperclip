"""Fix bone rolls WITHOUT touching weights.

Takes V2 model with its original weights intact, only zeroes the bone rolls.

Usage:
  blender --background --python _fix_rolls_only.py -- <input.glb> <output.glb>
"""
import bpy, sys, os

args = sys.argv[sys.argv.index("--") + 1:]
input_glb = args[0]
output_glb = args[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)

arm_obj = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        arm_obj = obj
        break

bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='EDIT')

for b in arm_obj.data.edit_bones:
    old = b.roll
    b.roll = 0.0
    if old != 0.0:
        print(f"  {b.name:20s}  {old:.3f} -> 0.000", flush=True)

bpy.ops.object.mode_set(mode='OBJECT')

bpy.ops.export_scene.gltf(filepath=output_glb, export_format='GLB')
size_kb = os.path.getsize(output_glb) // 1024
print(f"Done: {output_glb} ({size_kb} KB)", flush=True)
