"""Inspect bone structure of a rigged GLB — names, positions, hierarchy.

Usage: blender --background --python inspect-bones.py -- <rigged.glb>
"""
import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
glb_path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        arm = obj.data
        print(f"\nArmature: {obj.name} ({len(arm.bones)} bones)")
        print(f"{'Name':<20} {'Head (x,y,z)':<30} {'Tail (x,y,z)':<30} {'Parent':<20} {'Children'}")
        print("-" * 120)
        for bone in arm.bones:
            h = bone.head_local
            t = bone.tail_local
            parent = bone.parent.name if bone.parent else "(root)"
            children = ", ".join(c.name for c in bone.children) or "(leaf)"
            print(f"{bone.name:<20} ({h.x:+.3f},{h.y:+.3f},{h.z:+.3f})  ({t.x:+.3f},{t.y:+.3f},{t.z:+.3f})  {parent:<20} {children}")
