"""
Universal pet animation engine for Blender 5.
Inspects the skeleton, classifies bone roles (root, spine, limbs, extremities),
and generates Idle / Walk / Float animations for any rigged model.

Special handling for: jellyfish (pulsing dome + slow tendrils)

Usage (headless export):
  blender --background --python universal-animate.py -- input.glb output.glb [pet_name]

Usage (interactive preview):
  blender --python universal-animate.py -- input.glb
"""
import bpy
import math
import sys
import os

argv = sys.argv
args_after = argv[argv.index("--") + 1:] if "--" in argv else []
input_glb = args_after[0] if len(args_after) > 0 else ""
output_glb = args_after[1] if len(args_after) > 1 else ""
pet_name = args_after[2] if len(args_after) > 2 else ""

HEADLESS = "--background" in argv
FPS = 30


def osc(frame, total, cycles, amplitude, phase=0.0):
    t = (frame / total) * cycles * 2.0 * math.pi + phase
    return amplitude * math.sin(t)


def set_rot(pb, frame, x=0, y=0, z=0):
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
    pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def set_loc(pb, frame, x=0, y=0, z=0):
    pb.location = (x, y, z)
    pb.keyframe_insert(data_path="location", frame=frame)


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)


def key_all(arm_obj, f, overrides=None):
    """Key every bone, applying overrides by bone name."""
    overrides = overrides or {}
    for pb in arm_obj.pose.bones:
        vals = overrides.get(pb.name, {})
        set_rot(pb, f, x=vals.get("rx", 0), y=vals.get("ry", 0), z=vals.get("rz", 0))
        set_loc(pb, f, x=vals.get("lx", 0), y=vals.get("ly", 0), z=vals.get("lz", 0))


def analyze_skeleton(arm_obj):
    """Classify bones into roles based on hierarchy."""
    bones = arm_obj.data.bones
    bone_list = list(bones)
    n = len(bone_list)

    root = None
    for b in bone_list:
        if b.parent is None:
            root = b
            break
    if not root:
        root = bone_list[0]

    children_map = {b.name: [] for b in bone_list}
    for b in bone_list:
        if b.parent:
            children_map[b.parent.name].append(b.name)

    def chain_from(start):
        chain = [start]
        cur = start
        while children_map[cur]:
            if len(children_map[cur]) == 1:
                cur = children_map[cur][0]
                chain.append(cur)
            else:
                break
        return chain

    spine_chain = chain_from(root.name)

    branch_points = {}
    for bname in spine_chain:
        kids = children_map[bname]
        non_spine = [k for k in kids if k not in spine_chain]
        if non_spine:
            branch_points[bname] = non_spine

    limb_chains = []
    for parent, kids in branch_points.items():
        for kid in kids:
            lc = chain_from(kid)
            limb_chains.append({"parent": parent, "bones": lc})

    tips = [b.name for b in bone_list if not children_map[b.name]]

    return {
        "root": root.name,
        "spine": spine_chain,
        "branches": branch_points,
        "limbs": limb_chains,
        "tips": tips,
        "all": [b.name for b in bone_list],
        "count": n,
    }


def generic_idle(arm_obj, skel, T):
    spine = skel["spine"]
    limbs = skel["limbs"]
    n_spine = len(spine)

    for f in range(T):
        overrides = {}

        bob = osc(f, T, 1, 0.005)
        overrides[spine[0]] = {"lz": bob, "ry": osc(f, T, 1, 1.5)}

        for i, bname in enumerate(spine[1:], 1):
            depth = i / max(n_spine - 1, 1)
            wave = osc(f, T, 1, 3.0 * depth, phase=-0.4 * i)
            sway = osc(f, T, 1, 2.0 * depth, phase=0.3 * i)
            overrides[bname] = {"rx": wave, "rz": sway * 0.5}

        for li, limb in enumerate(limbs):
            phase_off = math.pi * li / max(len(limbs), 1)
            for j, bname in enumerate(limb["bones"]):
                depth = (j + 1) / len(limb["bones"])
                swing = osc(f, T, 1, 4.0 * depth, phase=phase_off - 0.3 * j)
                overrides[bname] = {"rx": swing, "rz": swing * 0.3}

        key_all(arm_obj, f, overrides)


def generic_walk(arm_obj, skel, T):
    spine = skel["spine"]
    limbs = skel["limbs"]
    n_spine = len(spine)

    for f in range(T):
        overrides = {}

        bob = osc(f, T, 2, 0.006)
        sway = osc(f, T, 1, 2.0)
        overrides[spine[0]] = {"lz": bob, "ry": sway}

        for i, bname in enumerate(spine[1:], 1):
            depth = i / max(n_spine - 1, 1)
            pitch = osc(f, T, 2, 2.5 * depth, phase=-0.3 * i)
            overrides[bname] = {"rx": pitch}

        for li, limb in enumerate(limbs):
            phase_off = math.pi * li / max(len(limbs), 1)
            for j, bname in enumerate(limb["bones"]):
                depth = (j + 1) / len(limb["bones"])
                stride = osc(f, T, 1, 18.0 * depth, phase=phase_off)
                overrides[bname] = {"rx": stride}

        key_all(arm_obj, f, overrides)


def generic_float(arm_obj, skel, T):
    spine = skel["spine"]
    limbs = skel["limbs"]
    n_spine = len(spine)

    for f in range(T):
        overrides = {}

        hover = osc(f, T, 1, 0.008)
        drift = osc(f, T, 1, 0.004, phase=0.5)
        yaw = osc(f, T, 1, 3.0)
        overrides[spine[0]] = {"lz": 0.03 + hover, "ly": drift, "rz": yaw * 0.3}

        for i, bname in enumerate(spine[1:], 1):
            depth = i / max(n_spine - 1, 1)
            wave = osc(f, T, 1, 5.0 * depth, phase=-0.5 * i)
            overrides[bname] = {"rx": wave}

        for li, limb in enumerate(limbs):
            phase_off = math.pi * li / max(len(limbs), 1)
            for j, bname in enumerate(limb["bones"]):
                depth = (j + 1) / len(limb["bones"])
                float_wave = osc(f, T, 1, 6.0 * depth, phase=phase_off - 0.4 * j)
                overrides[bname] = {"rz": float_wave, "rx": float_wave * 0.5}

        key_all(arm_obj, f, overrides)


# ── Jellyfish-specific animations ──

def jelly_idle(arm_obj, skel, T):
    """Pulsing dome + very slow tendril sway."""
    spine = skel["spine"]
    limbs = skel["limbs"]

    for f in range(T):
        overrides = {}
        pulse = osc(f, T, 2, 0.004)
        overrides[spine[0]] = {"lz": pulse}

        for i, bname in enumerate(spine[1:], 1):
            depth = i / max(len(spine) - 1, 1)
            undulate = osc(f, T, 1, 3.0 * depth, phase=-0.6 * i)
            overrides[bname] = {"rx": undulate}

        for li, limb in enumerate(limbs):
            phase_off = (math.pi * 2 * li) / max(len(limbs), 1)
            for j, bname in enumerate(limb["bones"]):
                depth = (j + 1) / len(limb["bones"])
                sway = osc(f, T, 0.5, 8.0 * depth, phase=phase_off - 0.8 * j)
                drift = osc(f, T, 0.5, 5.0 * depth, phase=phase_off + 0.3)
                overrides[bname] = {"rx": sway, "rz": drift}

        key_all(arm_obj, f, overrides)


def jelly_walk(arm_obj, skel, T):
    """Propulsion pulses with faster tendril flow."""
    spine = skel["spine"]
    limbs = skel["limbs"]

    for f in range(T):
        overrides = {}
        propulsion = osc(f, T, 3, 0.008)
        squeeze = osc(f, T, 3, 2.0)
        overrides[spine[0]] = {"lz": propulsion, "rx": squeeze * 0.5}

        for i, bname in enumerate(spine[1:], 1):
            depth = i / max(len(spine) - 1, 1)
            wave = osc(f, T, 3, 4.0 * depth, phase=-0.5 * i)
            overrides[bname] = {"rx": wave}

        for li, limb in enumerate(limbs):
            phase_off = (math.pi * 2 * li) / max(len(limbs), 1)
            for j, bname in enumerate(limb["bones"]):
                depth = (j + 1) / len(limb["bones"])
                trail = osc(f, T, 1, 12.0 * depth, phase=phase_off - 1.0 * j)
                curl = osc(f, T, 1, 6.0 * depth, phase=phase_off + 0.5)
                overrides[bname] = {"rx": trail, "rz": curl}

        key_all(arm_obj, f, overrides)


def jelly_float(arm_obj, skel, T):
    """Very slow drift with gentle tendril trail."""
    spine = skel["spine"]
    limbs = skel["limbs"]

    for f in range(T):
        overrides = {}
        hover = osc(f, T, 1, 0.006)
        drift_y = osc(f, T, 1, 0.003, phase=0.7)
        yaw = osc(f, T, 1, 4.0)
        overrides[spine[0]] = {"lz": 0.03 + hover, "ly": drift_y, "rz": yaw * 0.2}

        for i, bname in enumerate(spine[1:], 1):
            depth = i / max(len(spine) - 1, 1)
            wave = osc(f, T, 0.5, 2.0 * depth, phase=-0.4 * i)
            overrides[bname] = {"rx": wave}

        for li, limb in enumerate(limbs):
            phase_off = (math.pi * 2 * li) / max(len(limbs), 1)
            for j, bname in enumerate(limb["bones"]):
                depth = (j + 1) / len(limb["bones"])
                gentle = osc(f, T, 0.5, 6.0 * depth, phase=phase_off - 0.6 * j)
                sway = osc(f, T, 0.5, 4.0 * depth, phase=phase_off + 1.0)
                overrides[bname] = {"rx": gentle, "rz": sway}

        key_all(arm_obj, f, overrides)


ANIM_SETS = {
    "jellyfish": [
        ("Idle", jelly_idle, 3.0),
        ("Walk", jelly_walk, 1.5),
        ("Float", jelly_float, 4.0),
    ],
    "_generic": [
        ("Idle", generic_idle, 2.0),
        ("Walk", generic_walk, 1.0),
        ("Float", generic_float, 3.0),
    ],
}


# ── Build & Export ──

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)

bpy.context.scene.render.fps = FPS
print(f"Importing: {input_glb}")
bpy.ops.import_scene.gltf(filepath=input_glb)

arm_obj = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        arm_obj = obj
        break

if not arm_obj:
    print("ERROR: No armature found in model")
    sys.exit(1)

bone_count = len(arm_obj.data.bones)
bone_names = [b.name for b in arm_obj.data.bones]
print(f"Skeleton: {bone_count} bones: {bone_names}")

skel = analyze_skeleton(arm_obj)
print(f"Root: {skel['root']}, Spine: {skel['spine']}, Limbs: {len(skel['limbs'])}")

anim_set = ANIM_SETS.get(pet_name, ANIM_SETS["_generic"])
print(f"Using animation set: {'jellyfish' if pet_name == 'jellyfish' else 'generic'}")

bpy.context.view_layer.objects.active = arm_obj
if arm_obj.animation_data is None:
    arm_obj.animation_data_create()

actions = {}
for anim_name, anim_fn, duration in anim_set:
    total_frames = int(FPS * duration)
    bpy.ops.object.mode_set(mode="POSE")
    reset_pose(arm_obj)

    action = bpy.data.actions.new(name=anim_name)
    action.use_fake_user = True
    arm_obj.animation_data.action = action

    anim_fn(arm_obj, skel, total_frames)
    bpy.ops.object.mode_set(mode="OBJECT")
    actions[anim_name] = (action, total_frames)
    print(f"  Created: {anim_name} ({total_frames} frames, {duration}s)")

arm_obj.animation_data.action = None

if HEADLESS and output_glb:
    for track in list(arm_obj.animation_data.nla_tracks):
        arm_obj.animation_data.nla_tracks.remove(track)

    for anim_name, _, dur in anim_set:
        if anim_name not in actions:
            continue
        action, total_frames = actions[anim_name]
        track = arm_obj.animation_data.nla_tracks.new()
        track.name = anim_name
        strip = track.strips.new(anim_name, start=0, action=action)
        strip.frame_end = total_frames - 1
        track.mute = False

    bpy.ops.export_scene.gltf(
        filepath=output_glb,
        export_format="GLB",
        export_animations=True,
        export_nla_strips=True,
        export_anim_single_armature=True,
    )
    print(f"Exported: {output_glb}")
else:
    _actions = actions
    _anim_defs = anim_set
    _arm_obj = arm_obj
    _op_ids = {}

    def activate_animation(name):
        if name not in _actions:
            return
        action, total_frames = _actions[name]
        scene = bpy.context.scene
        _arm_obj.animation_data.action = action
        scene.frame_start = 0
        scene.frame_end = total_frames - 1
        try:
            bpy.ops.screen.animation_cancel(restore_frame=False)
        except Exception:
            pass
        scene.frame_set(0)
        try:
            bpy.ops.screen.animation_play()
        except Exception:
            pass

    def _make_operator(anim_name):
        idname = f"anim_preview.play_{anim_name.lower()}"
        def execute(self, context):
            activate_animation(anim_name)
            return {"FINISHED"}
        cls = type(
            f"ANIM_OT_play_{anim_name.lower()}",
            (bpy.types.Operator,),
            {"bl_idname": idname, "bl_label": f"Play {anim_name}",
             "bl_description": f"Switch to {anim_name}", "execute": execute},
        )
        bpy.utils.register_class(cls)
        _op_ids[anim_name] = idname

    class ANIM_PT_preview(bpy.types.Panel):
        bl_label = "Animations"
        bl_idname = "ANIM_PT_preview"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Anim"
        def draw(self, context):
            layout = self.layout
            layout.scale_y = 2.0
            current = _arm_obj.animation_data.action if _arm_obj.animation_data else None
            for anim_name, _, dur in _anim_defs:
                if anim_name not in _op_ids:
                    continue
                action, tf = _actions.get(anim_name, (None, 0))
                row = layout.row()
                row.alert = (action is not None and current == action)
                row.operator(_op_ids[anim_name],
                             text=f"{anim_name} ({tf}f / {dur}s)",
                             icon="PAUSE" if row.alert else "PLAY")

    for anim_name, _, _ in anim_set:
        _make_operator(anim_name)
    bpy.utils.register_class(ANIM_PT_preview)

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "MATERIAL"
                    space.overlay.show_bones = False
                    space.overlay.show_cursor = False
                    space.show_gizmo = False
            with bpy.context.temp_override(area=area, region=area.regions[-1]):
                bpy.ops.view3d.view_selected()
            break

    activate_animation(anim_set[0][0])

bpy.context.preferences.view.show_splash = False
