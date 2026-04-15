"""Inspect the HY-Motion FBX: list armature bones and animation data."""
import bpy, sys

fbx_path = sys.argv[sys.argv.index("--") + 1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx_path)

for obj in bpy.data.objects:
    print(f"Object: {obj.name}  Type: {obj.type}", flush=True)
    if obj.type == "ARMATURE":
        arm = obj.data
        print(f"  Bones ({len(arm.bones)}):", flush=True)
        for b in arm.bones:
            parent = b.parent.name if b.parent else "ROOT"
            print(f"    {b.name}  parent={parent}  head={[round(c,3) for c in b.head_local]}  tail={[round(c,3) for c in b.tail_local]}", flush=True)
        if obj.animation_data and obj.animation_data.action:
            act = obj.animation_data.action
            print(f"  Action: {act.name}  curves={len(act.fcurves)}  frames={act.frame_range[0]:.0f}-{act.frame_range[1]:.0f}", flush=True)
            bones_animated = set()
            for fc in act.fcurves:
                if fc.data_path.startswith("pose.bones"):
                    bname = fc.data_path.split('"')[1]
                    bones_animated.add(bname)
            print(f"  Animated bones ({len(bones_animated)}): {sorted(bones_animated)}", flush=True)

for act in bpy.data.actions:
    print(f"\nAction: {act.name}  curves={len(act.fcurves)}  frames={act.frame_range[0]:.0f}-{act.frame_range[1]:.0f}", flush=True)
