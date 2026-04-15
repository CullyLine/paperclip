"""Retarget HY-Motion FBX animation onto the Tung Tung Sahur rigged GLB.

Usage:
  blender --background --python _retarget_animation.py -- <character.glb> <animation.fbx> <output.glb>

Maps the 52-bone HY-Motion skeleton to our 17-bone custom skeleton,
bakes the animation, and exports the animated character.
"""
import bpy, sys, os
from mathutils import Matrix, Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
char_glb = args[0]
anim_fbx = args[1]
out_glb  = args[2]

BONE_MAP = {
    "hips":        "Pelvis",
    "spine":       "Spine1",
    "spine2":      "Spine2",
    "chest":       "Spine3",
    "neck":        "Neck",
    "head":        "Head",
    "collar_L":    "L_Collar",
    "upper_arm_L": "L_Shoulder",
    "forearm_L":   "L_Elbow",
    "hand_L":      "L_Wrist",
    "collar_R":    "R_Collar",
    "upper_arm_R": "R_Shoulder",
    "forearm_R":   "R_Elbow",
    "hand_R":      "R_Wrist",
    "upper_leg_L": "L_Hip",
    "lower_leg_L": "L_Knee",
    "foot_L":      "L_Ankle",
    "toe_L":       "L_Foot",
    "upper_leg_R": "R_Hip",
    "lower_leg_R": "R_Knee",
    "foot_R":      "R_Ankle",
    "toe_R":       "R_Foot",
}

bpy.ops.wm.read_factory_settings(use_empty=True)

print("Importing character GLB...", flush=True)
bpy.ops.import_scene.gltf(filepath=char_glb)

char_arm = None
char_mesh = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        char_arm = obj
    elif obj.type == "MESH":
        char_mesh = obj

if not char_arm:
    sys.exit("No armature found in character GLB")

print(f"Character armature: {char_arm.name}, bones: {len(char_arm.data.bones)}", flush=True)

print("Importing animation FBX...", flush=True)
bpy.ops.import_scene.fbx(filepath=anim_fbx)

anim_arm = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE" and obj != char_arm:
        anim_arm = obj
        break

if not anim_arm:
    sys.exit("No armature found in animation FBX")

anim_action = None
if anim_arm.animation_data and anim_arm.animation_data.action:
    anim_action = anim_arm.animation_data.action
else:
    for act in bpy.data.actions:
        anim_action = act
        break

if not anim_action:
    sys.exit("No animation action found")

print(f"Animation: {anim_action.name}, frames {anim_action.frame_range[0]:.0f}-{anim_action.frame_range[1]:.0f}", flush=True)

frame_start = int(anim_action.frame_range[0])
frame_end   = int(anim_action.frame_range[1])

bpy.context.view_layer.objects.active = anim_arm
anim_arm.animation_data.action = anim_action

anim_rest = {}
for b in anim_arm.data.bones:
    anim_rest[b.name] = b.matrix_local.copy()

char_rest = {}
for b in char_arm.data.bones:
    char_rest[b.name] = b.matrix_local.copy()

new_action = bpy.data.actions.new(name="griddy")
if not char_arm.animation_data:
    char_arm.animation_data_create()
char_arm.animation_data.action = new_action

# --- Capture the pelvis location at frame 1 as the "neutral" reference ---
bpy.context.scene.frame_set(frame_start)
pelvis_pb = anim_arm.pose.bones.get("Pelvis")
pelvis_neutral_loc = pelvis_pb.location.copy() if pelvis_pb else Vector((0, 0, 0))
print(f"Pelvis neutral location (frame {frame_start}): {[round(v,4) for v in pelvis_neutral_loc]}", flush=True)

# The HY-Motion SMPL skeleton is ~1.7m tall in its own space.
# The .location values on Pelvis are in bone-local space and are in cm-ish scale.
# We need to convert the DELTA from neutral into our character's scale.
# Our character's hips bone length gives us a sense of local scale.
char_hips_bone = char_arm.data.bones.get("hips")
char_hips_len = char_hips_bone.length if char_hips_bone else 0.1

# Pelvis bone length in the anim skeleton
anim_pelvis_bone = anim_arm.data.bones.get("Pelvis")
anim_pelvis_len = anim_pelvis_bone.length if anim_pelvis_bone else 11.0

loc_scale = char_hips_len / max(anim_pelvis_len, 0.001)

# Amplify movement so it reads well on a low-poly character
ROT_AMPLIFY = 1.5    # 1.0 = original, 1.5 = 50% more dramatic rotations
LOC_AMPLIFY = 3.0    # boost hip translations so the bounce is visible

loc_scale *= LOC_AMPLIFY

print(f"Char hips bone length: {char_hips_len:.4f}", flush=True)
print(f"Anim Pelvis bone length: {anim_pelvis_len:.4f}", flush=True)
print(f"Location scale factor (with {LOC_AMPLIFY}x amplify): {loc_scale:.6f}", flush=True)
print(f"Rotation amplify: {ROT_AMPLIFY}x", flush=True)

bpy.context.view_layer.objects.active = anim_arm
bpy.context.scene.frame_start = frame_start
bpy.context.scene.frame_end = frame_end

print("Retargeting animation...", flush=True)

for frame in range(frame_start, frame_end + 1):
    bpy.context.scene.frame_set(frame)

    for char_bone_name, anim_bone_name in BONE_MAP.items():
        if char_bone_name not in char_arm.pose.bones:
            continue
        if anim_bone_name not in anim_arm.pose.bones:
            continue

        anim_pb = anim_arm.pose.bones[anim_bone_name]
        char_pb = char_arm.pose.bones[char_bone_name]

        anim_bone_rest = anim_rest.get(anim_bone_name)
        if anim_bone_rest is None:
            continue

        if anim_pb.parent:
            anim_parent_rest = anim_rest.get(anim_pb.parent.name)
            local_posed = anim_pb.parent.matrix.inverted() @ anim_pb.matrix
            local_rest = anim_parent_rest.inverted() @ anim_bone_rest if anim_parent_rest else anim_bone_rest
        else:
            local_posed = anim_pb.matrix
            local_rest = anim_bone_rest

        delta = local_rest.inverted() @ local_posed
        rot_delta = delta.to_quaternion()

        # Amplify rotations via axis-angle scaling
        if ROT_AMPLIFY != 1.0:
            axis, angle = rot_delta.to_axis_angle()
            rot_delta = Quaternion(axis, angle * ROT_AMPLIFY)

        char_pb.rotation_mode = 'QUATERNION'
        char_pb.rotation_quaternion = rot_delta

        if char_bone_name == "hips":
            # Only apply the DELTA from the neutral position, scaled down
            anim_loc = anim_pb.location.copy()
            delta_loc = anim_loc - pelvis_neutral_loc
            char_pb.location = delta_loc * loc_scale

        char_pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if char_bone_name == "hips":
            char_pb.keyframe_insert(data_path="location", frame=frame)

    if frame % 30 == 0:
        anim_hips = anim_arm.pose.bones.get("Pelvis")
        char_hips = char_arm.pose.bones.get("hips")
        if anim_hips and char_hips:
            delta_l = anim_hips.location - pelvis_neutral_loc
            print(f"  Frame {frame}/{frame_end}  delta={[round(v,3) for v in delta_l]}  -> hips.loc={[round(v,4) for v in char_hips.location]}", flush=True)

print("Cleaning up animation objects...", flush=True)
for obj in list(bpy.data.objects):
    if obj != char_arm and obj != char_mesh:
        if obj.type in ("ARMATURE", "MESH", "EMPTY"):
            bpy.data.objects.remove(obj, do_unlink=True)

# Lock the scene range so the GLB animation ends at the last keyframe
bpy.context.scene.frame_start = frame_start
bpy.context.scene.frame_end = frame_end
new_action.frame_range = (frame_start, frame_end)
new_action.use_frame_range = True

print(f"Animation range locked to frames {frame_start}-{frame_end}", flush=True)
print(f"Exporting to {out_glb}...", flush=True)
bpy.ops.export_scene.gltf(
    filepath=out_glb,
    export_format='GLB',
    export_animations=True,
    export_skins=True,
    export_frame_range=True,
)

size_kb = os.path.getsize(out_glb) // 1024
print(f"Done! {out_glb} ({size_kb} KB)", flush=True)
