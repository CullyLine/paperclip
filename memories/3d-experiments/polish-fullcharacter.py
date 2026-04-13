"""Visual polish for full-character assets (non-chibi).

Minimal adjustments to preserve original look:
- Shade smooth (normals only)
- Saturation +10% (subtle vibrancy without cartoonifying)
- Contrast +5% (gentle definition)
- No brightness boost
- AO bake with 0.6 strength (more depth for realistic look)

Usage: blender --background --python polish-fullcharacter.py -- <input.glb> <output.glb>
"""
import bpy
import sys
import numpy as np

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.cycles.samples = 32

for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    face_count = len(obj.data.polygons)
    print(f"\nPolishing (full-character) {obj.name}: {face_count} faces")

    bpy.ops.object.shade_smooth()
    if hasattr(obj.data, 'use_auto_smooth'):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = 1.0472
    print("  [1] Shade smooth: done")

    diffuse_img = None
    if obj.data.materials:
        for mat in obj.data.materials:
            if not mat or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    diffuse_img = node.image
                    break
            if diffuse_img:
                break

    if diffuse_img:
        w, h = diffuse_img.size
        pixels = np.array(diffuse_img.pixels[:]).reshape((h, w, 4))
        rgb = pixels[:, :, :3]

        gray = np.mean(rgb, axis=2, keepdims=True)
        rgb_boosted = gray + (rgb - gray) * 1.10
        rgb_boosted = np.clip(rgb_boosted, 0.0, 1.0)

        rgb_contrast = 0.5 + (rgb_boosted - 0.5) * 1.05
        rgb_contrast = np.clip(rgb_contrast, 0.0, 1.0)

        pixels[:, :, :3] = rgb_contrast
        diffuse_img.pixels = pixels.flatten().tolist()
        diffuse_img.pack()
        print("  [2] Texture: saturation +10%, contrast +5%, no brightness boost")
    else:
        print("  [2] No diffuse texture found, skipping")

    if diffuse_img:
        ao_img = bpy.data.images.new("AO_Bake", w, h, alpha=False)
        mat = obj.data.materials[0]
        nodes = mat.node_tree.nodes
        ao_tex_node = nodes.new('ShaderNodeTexImage')
        ao_tex_node.image = ao_img
        ao_tex_node.select = True
        nodes.active = ao_tex_node

        bpy.context.scene.cycles.bake_type = 'AO'
        bpy.context.scene.render.bake.use_selected_to_active = False

        try:
            bpy.ops.object.bake(type='AO')
            print("  [3] AO bake: done")

            ao_pixels = np.array(ao_img.pixels[:]).reshape((h, w, 4))
            ao_gray = ao_pixels[:, :, :3]
            ao_soft = 0.4 + ao_gray * 0.6

            current = np.array(diffuse_img.pixels[:]).reshape((h, w, 4))
            current[:, :, :3] *= ao_soft
            current[:, :, :3] = np.clip(current[:, :, :3], 0.0, 1.0)
            diffuse_img.pixels = current.flatten().tolist()
            diffuse_img.pack()
            print("  [3] AO multiply: applied (40% floor, 0.6 strength)")
        except Exception as e:
            print(f"  [3] AO bake failed: {e} (skipping)")

        nodes.remove(ao_tex_node)
        bpy.data.images.remove(ao_img)

    print(f"  Final: {len(obj.data.polygons)} faces")

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"\nExported polished model to {output_path}")
