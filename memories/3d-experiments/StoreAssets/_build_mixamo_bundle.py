"""Use Mixamo's rigged mesh directly, apply our texture, bundle all animations.

1. Import T-Pose.fbx (with skin) → Mixamo mesh + skeleton + perfect weights
2. Import our GLB → extract just the material/texture
3. Apply our texture to the Mixamo mesh
4. Import all animation FBXs
5. Export single GLB with all animations

Usage:
  blender --background --python _build_mixamo_bundle.py -- <our_mesh.glb> <tpose.fbx> <anim_dir> <output.glb>
"""
import bpy, sys, os, glob

args = sys.argv[sys.argv.index("--") + 1:]
our_glb    = args[0]
tpose_fbx  = args[1]
anim_dir   = args[2]
output_glb = args[3]

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- Step 1: Import Mixamo T-Pose (mesh + skeleton + weights) ---
print("=== Step 1: Import Mixamo T-Pose (with skin) ===", flush=True)
bpy.ops.import_scene.fbx(filepath=tpose_fbx)

mixamo_arm = None
mixamo_mesh = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        mixamo_arm = obj
    elif obj.type == "MESH":
        mixamo_mesh = obj

print(f"Mixamo armature: {mixamo_arm.name}, {len(mixamo_arm.data.bones)} bones", flush=True)
print(f"Mixamo mesh: {mixamo_mesh.name}, {len(mixamo_mesh.data.vertices)} verts", flush=True)

# Strip mixamorig: prefix from bones
bpy.context.view_layer.objects.active = mixamo_arm
bpy.ops.object.mode_set(mode='EDIT')
for bone in mixamo_arm.data.edit_bones:
    if bone.name.startswith("mixamorig:"):
        bone.name = bone.name.replace("mixamorig:", "")
bpy.ops.object.mode_set(mode='OBJECT')

# Strip prefix from vertex groups on Mixamo mesh
for vg in mixamo_mesh.vertex_groups:
    if vg.name.startswith("mixamorig:"):
        vg.name = vg.name.replace("mixamorig:", "")

print(f"Stripped mixamorig: prefix", flush=True)

# --- Step 2: Import our GLB to get the texture ---
print("\n=== Step 2: Import texture from our GLB ===", flush=True)
bpy.ops.import_scene.gltf(filepath=our_glb)

our_mesh = None
for obj in bpy.data.objects:
    if obj.type == "MESH" and obj != mixamo_mesh and obj.name != "Icosphere":
        our_mesh = obj

if our_mesh and our_mesh.data.materials:
    our_material = our_mesh.data.materials[0]
    print(f"Found material: {our_material.name}", flush=True)

    # Apply our material to the Mixamo mesh
    mixamo_mesh.data.materials.clear()
    mixamo_mesh.data.materials.append(our_material)
    print("Applied our texture to Mixamo mesh", flush=True)
else:
    print("WARNING: No material found on our mesh!", flush=True)

# Remove our mesh and any other leftover objects
for obj in list(bpy.data.objects):
    if obj != mixamo_arm and obj != mixamo_mesh:
        bpy.data.objects.remove(obj, do_unlink=True)

print(f"Final mesh: {len(mixamo_mesh.data.vertices)} verts, {len(mixamo_mesh.data.polygons)} faces, {len(mixamo_mesh.vertex_groups)} groups", flush=True)

# --- Step 3: Import animations ---
print("\n=== Step 3: Import animations ===", flush=True)

def strip_prefix_from_action(action):
    if not action:
        return
    if hasattr(action, "is_action_layered") and action.is_action_layered:
        for layer in action.layers:
            for strip in layer.strips:
                if hasattr(strip, "channelbags"):
                    for cb in strip.channelbags:
                        for fc in cb.fcurves:
                            fc.data_path = fc.data_path.replace("mixamorig:", "")
    elif hasattr(action, "fcurves"):
        for fc in action.fcurves:
            fc.data_path = fc.data_path.replace("mixamorig:", "")

all_actions = []

# Grab T-Pose action
if mixamo_arm.animation_data and mixamo_arm.animation_data.action:
    tpose_action = mixamo_arm.animation_data.action
    tpose_action.name = "T-Pose"
    strip_prefix_from_action(tpose_action)
    all_actions.append(tpose_action)
    print(f"  T-Pose", flush=True)

# Import each animation FBX
anim_files = sorted(glob.glob(os.path.join(anim_dir, "*.fbx")))
for fbx_path in anim_files:
    anim_name = os.path.splitext(os.path.basename(fbx_path))[0]
    if anim_name == "T-Pose":
        continue

    existing_actions = set(bpy.data.actions.keys())
    bpy.ops.import_scene.fbx(filepath=fbx_path)

    new_actions = [a for a in bpy.data.actions if a.name not in existing_actions]
    for act in new_actions:
        act.name = anim_name
        strip_prefix_from_action(act)
        all_actions.append(act)
        fr = act.curve_frame_range if hasattr(act, "curve_frame_range") else act.frame_range
        print(f"  {anim_name}: frames {fr[0]:.0f}-{fr[1]:.0f}", flush=True)

    # Clean up imported objects
    for obj in list(bpy.data.objects):
        if obj != mixamo_arm and obj != mixamo_mesh:
            if obj.type in ("ARMATURE", "MESH", "EMPTY"):
                bpy.data.objects.remove(obj, do_unlink=True)

print(f"\nTotal animations: {len(all_actions)}", flush=True)

# --- Step 4: Export GLB ---
print("\n=== Step 4: Export ===", flush=True)

if all_actions:
    mixamo_arm.animation_data.action = all_actions[0]

for action in all_actions:
    track = mixamo_arm.animation_data.nla_tracks.new()
    track.name = action.name
    fr = action.curve_frame_range if hasattr(action, "curve_frame_range") else action.frame_range
    strip = track.strips.new(action.name, int(fr[0]), action)
    strip.name = action.name

bpy.ops.export_scene.gltf(
    filepath=output_glb,
    export_format='GLB',
    export_animations=True,
    export_skins=True,
    export_nla_strips=True,
    export_animation_mode='ACTIONS',
)

size_mb = os.path.getsize(output_glb) / (1024 * 1024)
print(f"\nDone! {output_glb} ({size_mb:.1f} MB)", flush=True)
print(f"Contains: 1 textured mesh + {len(mixamo_arm.data.bones)} bones + {len(all_actions)} animations", flush=True)
for act in all_actions:
    print(f"  - {act.name}", flush=True)
