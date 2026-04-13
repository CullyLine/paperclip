import bpy
import sys

sys.stdout.reconfigure(line_buffering=True)

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]
target_faces = int(argv[2]) if len(argv) > 2 else 500
voxel_size = float(argv[3]) if len(argv) > 3 else 0.05

print(f"=== Decimate T-Pose ===", flush=True)
print(f"Input:  {input_path}", flush=True)
print(f"Output: {output_path}", flush=True)
print(f"Target: {target_faces} faces", flush=True)
print(f"Voxel:  {voxel_size}", flush=True)

print("\n[1/6] Loading GLB...", flush=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)
print("  Loaded.", flush=True)

bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.cycles.samples = 64
bpy.context.scene.cycles.bake_type = 'DIFFUSE'
bpy.context.scene.render.bake.use_pass_direct = False
bpy.context.scene.render.bake.use_pass_indirect = False
bpy.context.scene.render.bake.use_pass_color = True
bpy.context.scene.render.bake.use_selected_to_active = True
bpy.context.scene.render.bake.cage_extrusion = 0.05

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print(f"  Found {len(meshes)} mesh(es)", flush=True)

for obj in meshes:
    current_faces = len(obj.data.polygons)
    current_verts = len(obj.data.vertices)
    print(f"\n[2/6] Mesh: {obj.name} — {current_faces} faces, {current_verts} verts", flush=True)

    if current_faces <= target_faces:
        print(f"  Already at target, skipping decimation", flush=True)
        continue

    original = obj

    bpy.ops.object.select_all(action='DESELECT')
    original.select_set(True)
    bpy.context.view_layer.objects.active = original
    bpy.ops.object.duplicate()
    remeshed = bpy.context.active_object
    remeshed.name = original.name + "_lowpoly"

    print(f"\n[3/6] Voxel remesh (size={voxel_size})...", flush=True)
    voxel = remeshed.modifiers.new("Voxel", 'REMESH')
    voxel.mode = 'VOXEL'
    voxel.voxel_size = voxel_size
    voxel.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier="Voxel")

    mid_faces = len(remeshed.data.polygons)
    print(f"  After voxel: {mid_faces} faces", flush=True)

    print(f"\n[4/6] Collapse decimation to ~{target_faces}...", flush=True)
    iteration = 0
    while len(remeshed.data.polygons) > target_faces * 1.08:
        cur = len(remeshed.data.polygons)
        if cur <= target_faces:
            break
        ratio = max(0.03, min(0.999, target_faces / cur))
        dec = remeshed.modifiers.new("Decimate", 'DECIMATE')
        dec.decimate_type = 'COLLAPSE'
        dec.ratio = ratio
        bpy.ops.object.modifier_apply(modifier="Decimate")
        iteration += 1
        new_count = len(remeshed.data.polygons)
        print(f"  Pass {iteration}: {new_count} faces (ratio={ratio:.4f})", flush=True)
        if iteration > 12:
            break
        if new_count >= cur * 0.995:
            break

    print(f"\n[5/6] UV project + texture bake...", flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    remeshed.select_set(True)
    bpy.context.view_layer.objects.active = remeshed
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15192, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    bake_img = bpy.data.images.new("BakedTexture", 1024, 1024, alpha=False)
    mat = bpy.data.materials.new("BakedMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    tex_node = nodes.new('ShaderNodeTexImage')
    tex_node.image = bake_img
    tex_node.select = True
    nodes.active = tex_node
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    output_n = nodes.new('ShaderNodeOutputMaterial')
    links.new(bsdf.outputs['BSDF'], output_n.inputs['Surface'])
    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    remeshed.data.materials.clear()
    remeshed.data.materials.append(mat)

    bpy.ops.object.select_all(action='DESELECT')
    original.select_set(True)
    remeshed.select_set(True)
    bpy.context.view_layer.objects.active = remeshed

    print("  Baking textures...", flush=True)
    bpy.ops.object.bake(type='DIFFUSE')
    print("  Bake complete.", flush=True)

    bake_img.pack()

    bpy.ops.object.select_all(action='DESELECT')
    original.select_set(True)
    bpy.context.view_layer.objects.active = original
    bpy.ops.object.delete()
    remeshed.name = remeshed.name.replace("_lowpoly", "")

    final_faces = len(remeshed.data.polygons)
    print(f"\n[6/6] Final: {final_faces} faces with baked texture", flush=True)

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"\nExported to {output_path}", flush=True)
