"""Convert rigged GLBs to .blend files so they can be opened directly in Blender GUI.
Works around the Blender 5.0.1 armature_display bug on glTF import during --python startup.

Usage: blender --background --python convert-to-blend.py -- <input.glb> <output.blend>
"""
import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_glb = argv[0]
output_blend = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_glb)
bpy.ops.wm.save_as_mainfile(filepath=output_blend)
print(f"Saved {output_blend}")
