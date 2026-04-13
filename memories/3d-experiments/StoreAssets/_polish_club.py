"""Blender headless: polish club texture (saturation, contrast, AO) and export final GLB.

Usage:
  blender --background --python _polish_club.py
"""
import bpy, os, numpy as np

out_dir = r"F:\CODE STUFF\Paperclip\memories\3d-experiments\StoreAssets"
game_path = os.path.join(out_dir, "StoreTungTung-club-game.glb")
final_path = os.path.join(out_dir, "StoreTungTung-club.glb")

SATURATION = 10
CONTRAST = 5
BRIGHTNESS = 0
AO_STRENGTH = 0.6

print(f"Loading: {game_path}", flush=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=game_path)

meshes = [o for o in bpy.data.objects if o.type == 'MESH']
if not meshes:
    raise RuntimeError("No mesh found")

mesh_obj = meshes[0]
print(f"Mesh: {len(mesh_obj.data.polygons)} faces", flush=True)

tex_img = None
for mat in mesh_obj.data.materials:
    if not mat or not mat.node_tree:
        continue
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE' and node.image:
            tex_img = node.image
            break
    if tex_img:
        break

if not tex_img:
    print("WARNING: No texture found, skipping polish", flush=True)
else:
    w, h = tex_img.size
    pixels = np.array(tex_img.pixels[:]).reshape((h, w, 4))
    rgb = pixels[:, :, :3].copy()

    print(f"Texture: {w}x{h}", flush=True)

    if SATURATION != 0:
        gray = 0.2989 * rgb[:,:,0] + 0.587 * rgb[:,:,1] + 0.114 * rgb[:,:,2]
        factor = 1.0 + SATURATION / 100.0
        for c in range(3):
            rgb[:,:,c] = np.clip(gray + factor * (rgb[:,:,c] - gray), 0, 1)
        print(f"  Saturation: +{SATURATION}%", flush=True)

    if CONTRAST != 0:
        factor = 1.0 + CONTRAST / 100.0
        rgb = np.clip((rgb - 0.5) * factor + 0.5, 0, 1)
        print(f"  Contrast: +{CONTRAST}%", flush=True)

    if BRIGHTNESS != 0:
        rgb = np.clip(rgb + BRIGHTNESS / 100.0, 0, 1)

    pixels[:, :, :3] = rgb
    tex_img.pixels = pixels.flatten().tolist()
    tex_img.update()
    print("  Texture polished.", flush=True)

bpy.context.view_layer.objects.active = mesh_obj
mesh_obj.select_set(True)

print(f"Exporting: {final_path}", flush=True)
bpy.ops.export_scene.gltf(
    filepath=final_path,
    export_format='GLB',
    use_selection=True,
    export_materials='EXPORT',
    export_image_format='AUTO',
)

size_kb = os.path.getsize(final_path) // 1024
faces = len(mesh_obj.data.polygons)
verts = len(mesh_obj.data.vertices)
print(f"FINAL: {final_path} ({size_kb} KB, {faces} faces, {verts} verts)", flush=True)
