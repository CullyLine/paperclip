"""Apply a Mixamo FBX animation to our Mixamo-compatible rigged GLB.

Since bone names match exactly, we just transfer the action directly.
Compatible with Blender 5.x layered action system.

Usage:
  blender --background --python _apply_mixamo_anim.py -- <character.glb> <mixamo_anim.fbx> <output.glb>
"""
import bpy, sys, os

args = sys.argv[sys.argv.index("--") + 1:]
char_glb = args[0]
anim_fbx = args[1]
out_glb  = args[2]

def get_fcurves(action):
    """Get fcurves from action, handling both legacy and Blender 5.x layered actions."""
    if hasattr(action, "is_action_layered") and action.is_action_layered:
        for layer in action.layers:
            for strip in layer.strips:
                if hasattr(strip, "channelbags"):
                    for cb in strip.channelbags:
                        return cb.fcurves
    return action.fcurves

bpy.ops.wm.read_factory_settings(use_empty=True)

print("Importing character...", flush=True)
bpy.ops.import_scene.gltf(filepath=char_glb)

char_arm = None
char_mesh = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        char_arm = obj
    elif obj.type == "MESH":
        char_mesh = obj

print(f"Character: {char_arm.name}, {len(char_arm.data.bones)} bones", flush=True)

print("Importing Mixamo animation...", flush=True)
bpy.ops.import_scene.fbx(filepath=anim_fbx)

mixamo_arm = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE" and obj != char_arm:
        mixamo_arm = obj
        break

anim_action = None
if mixamo_arm and mixamo_arm.animation_data and mixamo_arm.animation_data.action:
    anim_action = mixamo_arm.animation_data.action
else:
    for act in bpy.data.actions:
        anim_action = act
        break

if not anim_action:
    sys.exit("No animation found in FBX")

frame_range = anim_action.curve_frame_range
print(f"Animation: {anim_action.name}, frames {frame_range[0]:.0f}-{frame_range[1]:.0f}", flush=True)

fcurves = get_fcurves(anim_action)
print(f"FCurves: {len(fcurves)}", flush=True)

# Strip "mixamorig:" prefix from fcurve paths
for fc in fcurves:
    fc.data_path = fc.data_path.replace("mixamorig:", "")

# Collect animated bone names
anim_bones = set()
for fc in fcurves:
    if "pose.bones" in fc.data_path:
        name = fc.data_path.split('"')[1]
        anim_bones.add(name)

# Apply action to our character
if not char_arm.animation_data:
    char_arm.animation_data_create()
char_arm.animation_data.action = anim_action

# If layered, update the slot binding to point to our armature
if hasattr(anim_action, "is_action_layered") and anim_action.is_action_layered:
    for slot in anim_action.slots:
        char_arm.animation_data.action_slot = slot
        break

frame_start = int(frame_range[0])
frame_end = int(frame_range[1])
bpy.context.scene.frame_start = frame_start
bpy.context.scene.frame_end = frame_end

char_bones = {b.name for b in char_arm.data.bones}
matched = anim_bones & char_bones
missing = anim_bones - char_bones
print(f"Bone match: {len(matched)}/{len(anim_bones)} animated bones found in character", flush=True)
if missing:
    print(f"Unmatched (ignored): {sorted(missing)}", flush=True)

# Clean up Mixamo objects
for obj in list(bpy.data.objects):
    if obj != char_arm and obj != char_mesh:
        bpy.data.objects.remove(obj, do_unlink=True)

print(f"Exporting {out_glb}...", flush=True)
bpy.ops.export_scene.gltf(
    filepath=out_glb,
    export_format='GLB',
    export_animations=True,
    export_skins=True,
    export_frame_range=True,
)

size_kb = os.path.getsize(out_glb) // 1024
print(f"Done! {out_glb} ({size_kb} KB), frames {frame_start}-{frame_end}", flush=True)
