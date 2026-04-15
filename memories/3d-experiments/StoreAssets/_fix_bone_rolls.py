"""Fix bone rolls to match Mixamo convention.

Mixamo expects consistent rolls so animation rotations bend joints correctly.

Usage:
  blender --background --python _fix_bone_rolls.py -- <input.glb> <output.glb>
"""
import bpy, sys, os, math

args = sys.argv[sys.argv.index("--") + 1:]
input_glb = args[0]
output_glb = args[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)

arm_obj = None
mesh_obj = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        arm_obj = obj
    elif obj.type == "MESH":
        mesh_obj = obj

bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='EDIT')

for b in arm_obj.data.edit_bones:
    old_roll = b.roll

    # Vertical bones (spine, legs) — roll = 0
    if b.name in ("Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
                   "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"):
        b.roll = 0.0

    # Horizontal arm bones — roll = 0
    elif b.name in ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
                     "RightShoulder", "RightArm", "RightForeArm", "RightHand"):
        b.roll = 0.0

    # Feet point forward-down — need roll so top of foot faces up
    elif b.name in ("LeftFoot", "LeftToeBase"):
        b.roll = 0.0
    elif b.name in ("RightFoot", "RightToeBase"):
        b.roll = 0.0

    print(f"  {b.name:20s}  roll {old_roll:.3f} -> {b.roll:.3f}", flush=True)

bpy.ops.object.mode_set(mode='OBJECT')

# Re-apply automatic weights with corrected rolls
mesh_obj.vertex_groups.clear()
for mod in list(mesh_obj.modifiers):
    if mod.type == 'ARMATURE':
        mesh_obj.modifiers.remove(mod)
mesh_obj.parent = None

bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

total = len(mesh_obj.data.vertices)
weighted = sum(1 for v in mesh_obj.data.vertices if len(v.groups) > 0)
print(f"Weight coverage: {weighted}/{total} ({weighted/max(total,1)*100:.1f}%)", flush=True)

bpy.ops.export_scene.gltf(filepath=output_glb, export_format='GLB')
size_kb = os.path.getsize(output_glb) // 1024
print(f"Exported: {output_glb} ({size_kb} KB)", flush=True)
