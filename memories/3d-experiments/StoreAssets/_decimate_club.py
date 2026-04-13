"""Blender headless: decimate club highpoly to ~150 faces + bake texture.
No rigging needed — pure prop asset.

Usage:
  blender --background --python _decimate_club.py
"""
import bpy, os, sys, bmesh

out_dir = r"F:\CODE STUFF\Paperclip\memories\3d-experiments\StoreAssets"
hp_path = os.path.join(out_dir, "StoreTungTung-club-highpoly.glb")
game_path = os.path.join(out_dir, "StoreTungTung-club-game.glb")
TARGET_FACES = 150
VOXEL_SIZE = 0.025

print(f"Loading highpoly: {hp_path}", flush=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=hp_path)

meshes = [o for o in bpy.data.objects if o.type == 'MESH']
print(f"Found {len(meshes)} mesh(es)", flush=True)

if len(meshes) > 1:
    bpy.context.view_layer.objects.active = meshes[0]
    for m in meshes:
        m.select_set(True)
    bpy.ops.object.join()
    meshes = [bpy.context.active_object]

hp_obj = meshes[0]
hp_faces = len(hp_obj.data.polygons)
print(f"Highpoly: {hp_faces} faces", flush=True)

lp_obj = hp_obj.copy()
lp_obj.data = hp_obj.data.copy()
lp_obj.name = "LowPoly"
bpy.context.collection.objects.link(lp_obj)
bpy.context.view_layer.objects.active = lp_obj

print(f"Voxel remesh at {VOXEL_SIZE}...", flush=True)
lp_obj.data.remesh_voxel_size = VOXEL_SIZE
bpy.ops.object.voxel_remesh()
after_voxel = len(lp_obj.data.polygons)
print(f"After voxel: {after_voxel} faces", flush=True)

passes = 0
while len(lp_obj.data.polygons) > TARGET_FACES * 1.08 and passes < 20:
    current = len(lp_obj.data.polygons)
    ratio = max(0.3, TARGET_FACES / current)
    mod = lp_obj.modifiers.new("Dec", 'DECIMATE')
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)
    new_count = len(lp_obj.data.polygons)
    print(f"  Pass {passes}: {current} -> {new_count} (ratio={ratio:.3f})", flush=True)
    if new_count >= current:
        break
    passes += 1

final_faces = len(lp_obj.data.polygons)
final_verts = len(lp_obj.data.vertices)
print(f"Final lowpoly: {final_faces} faces, {final_verts} verts", flush=True)

print("UV unwrapping lowpoly...", flush=True)
bpy.context.view_layer.objects.active = lp_obj
lp_obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(island_margin=0.02)
bpy.ops.object.mode_set(mode='OBJECT')

print("Setting up bake...", flush=True)
bake_img = bpy.data.images.new("BakeTexture", 1024, 1024, alpha=False)

mat = bpy.data.materials.new("BakedMat")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
nodes.clear()

tex_node = nodes.new('ShaderNodeTexImage')
tex_node.image = bake_img
tex_node.name = "BakeTarget"

bsdf = nodes.new('ShaderNodeBsdfPrincipled')
output = nodes.new('ShaderNodeOutputMaterial')
links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

lp_obj.data.materials.clear()
lp_obj.data.materials.append(mat)

for node in nodes:
    node.select = False
tex_node.select = True
nodes.active = tex_node

bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.cycles.samples = 32
bpy.context.scene.cycles.bake_type = 'DIFFUSE'
bpy.context.scene.render.bake.use_pass_direct = False
bpy.context.scene.render.bake.use_pass_indirect = False
bpy.context.scene.render.bake.use_pass_color = True
bpy.context.scene.render.bake.use_selected_to_active = True
bpy.context.scene.render.bake.cage_extrusion = 0.05
bpy.context.scene.render.bake.max_ray_distance = 0.1

hp_obj.select_set(True)
lp_obj.select_set(True)
bpy.context.view_layer.objects.active = lp_obj

print("Baking texture from highpoly -> lowpoly...", flush=True)
bpy.ops.object.bake(type='DIFFUSE')
print("Bake complete.", flush=True)

tex_path = os.path.join(out_dir, "club_baked_texture.png")
bake_img.filepath_raw = tex_path
bake_img.file_format = 'PNG'
bake_img.save()
print(f"Texture saved: {tex_path}", flush=True)

hp_obj.select_set(False)
bpy.data.objects.remove(hp_obj, do_unlink=True)
lp_obj.select_set(True)

print(f"Exporting: {game_path}", flush=True)
bpy.ops.export_scene.gltf(
    filepath=game_path,
    export_format='GLB',
    use_selection=True,
    export_materials='EXPORT',
    export_image_format='AUTO',
)

size_kb = os.path.getsize(game_path) // 1024
print(f"Done: {game_path} ({size_kb} KB, {final_faces} faces, {final_verts} verts)", flush=True)
