import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]
target_faces = int(argv[2]) if len(argv) > 2 else 2000
voxel_size = float(argv[3]) if len(argv) > 3 else 0.005

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

# Use Cycles for texture baking
bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.cycles.samples = 64
bpy.context.scene.cycles.bake_type = 'DIFFUSE'
bpy.context.scene.render.bake.use_pass_direct = False
bpy.context.scene.render.bake.use_pass_indirect = False
bpy.context.scene.render.bake.use_pass_color = True
bpy.context.scene.render.bake.use_selected_to_active = True
bpy.context.scene.render.bake.cage_extrusion = 0.05

for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue

    current_faces = len(obj.data.polygons)
    print(f"Input: {obj.name} — {current_faces} faces")

    if current_faces <= target_faces:
        print(f"Already below target, skipping")
        continue

    original = obj

    # Duplicate the original (keep it as texture source)
    bpy.ops.object.select_all(action='DESELECT')
    original.select_set(True)
    bpy.context.view_layer.objects.active = original
    bpy.ops.object.duplicate()
    remeshed = bpy.context.active_object
    remeshed.name = original.name + "_lowpoly"

    # Step 1: Voxel remesh the duplicate (watertight, no gaps)
    voxel = remeshed.modifiers.new("Voxel", 'REMESH')
    voxel.mode = 'VOXEL'
    voxel.voxel_size = voxel_size
    voxel.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier="Voxel")

    mid_faces = len(remeshed.data.polygons)
    print(f"After voxel remesh (size={voxel_size}): {mid_faces} faces")

    # Step 2: Decimate if still above target
    if mid_faces > target_faces:
        ratio = target_faces / mid_faces
        dec = remeshed.modifiers.new("Decimate", 'DECIMATE')
        dec.decimate_type = 'COLLAPSE'
        dec.ratio = ratio
        bpy.ops.object.modifier_apply(modifier="Decimate")
        print(f"After decimate: {len(remeshed.data.polygons)} faces")

    # Step 3: Smart UV Project so we have UVs for texture baking
    bpy.ops.object.select_all(action='DESELECT')
    remeshed.select_set(True)
    bpy.context.view_layer.objects.active = remeshed
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15192, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    # Step 4: Create bake target image and material
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
    output = nodes.new('ShaderNodeOutputMaterial')
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])

    remeshed.data.materials.clear()
    remeshed.data.materials.append(mat)

    # Step 5: Bake from original → remeshed
    bpy.ops.object.select_all(action='DESELECT')
    original.select_set(True)
    remeshed.select_set(True)
    bpy.context.view_layer.objects.active = remeshed

    print("Baking textures from original to low-poly...")
    bpy.ops.object.bake(type='DIFFUSE')
    print("Bake complete")

    # Pack the image so it exports with the GLB
    bake_img.pack()

    # Delete the original high-poly mesh
    bpy.ops.object.select_all(action='DESELECT')
    original.select_set(True)
    bpy.context.view_layer.objects.active = original
    bpy.ops.object.delete()

    # Rename lowpoly back
    remeshed.name = remeshed.name.replace("_lowpoly", "")

    final_faces = len(remeshed.data.polygons)
    print(f"Final: {final_faces} faces with baked texture")

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported to {output_path}")
