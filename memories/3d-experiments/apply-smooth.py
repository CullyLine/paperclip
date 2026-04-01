"""Blender script: apply shade smooth + corrective smooth to a GLB.

Usage: blender --background --python apply-smooth.py -- <input.glb> <output.glb>
"""
import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    face_count = len(obj.data.polygons)
    print(f"Smoothing {obj.name}: {face_count} faces")

    # Shade smooth (normal interpolation, no geometry change)
    bpy.ops.object.shade_smooth()

    # Auto smooth for sharp edges where angle > 60 degrees
    if hasattr(obj.data, 'use_auto_smooth'):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = 1.0472  # 60 degrees

    # Light corrective smooth (preserves volume better than laplacian)
    mod = obj.modifiers.new("ToySmooth", 'CORRECTIVE_SMOOTH')
    mod.iterations = 3
    mod.scale = 0.5
    mod.smooth_type = 'LENGTH_WEIGHTED'
    bpy.ops.object.modifier_apply(modifier="ToySmooth")

    final_faces = len(obj.data.polygons)
    print(f"  Done: {final_faces} faces (unchanged)")

    obj.select_set(False)

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported to {output_path}")
