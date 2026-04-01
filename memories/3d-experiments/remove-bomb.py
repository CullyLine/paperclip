"""Remove the bomb/nuke geometry hanging below bombardiro's body.

Imports the high-poly GLB, selects vertices in the lower portion that form
the bomb shape, deletes them, then exports a cleaned high-poly GLB.

Usage: blender --background --python remove-bomb.py -- <input.glb> <output.glb>
"""
import bpy
import sys
import bmesh

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]
output_path = argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if not meshes:
    print("No mesh found")
    sys.exit(1)

target = meshes[0]
for m in meshes:
    if len(m.data.vertices) > len(target.data.vertices):
        target = m

bpy.context.view_layer.objects.active = target
target.select_set(True)

bb = [target.matrix_world @ v.co.copy() for v in target.data.vertices]
min_z = min(v.z for v in bb)
max_z = max(v.z for v in bb)
min_x = min(v.x for v in bb)
max_x = max(v.x for v in bb)
min_y = min(v.y for v in bb)
max_y = max(v.y for v in bb)

height = max_z - min_z
width = max_x - min_x
depth = max_y - min_y
cx = (min_x + max_x) / 2
cy = (min_y + max_y) / 2

cutoff_z = min_z + height * 0.25
narrow_x = width * 0.25
narrow_y = depth * 0.25

print(f"Bounding box: Z=[{min_z:.3f}, {max_z:.3f}], height={height:.3f}")
print(f"Cutoff Z: {cutoff_z:.3f}, center=({cx:.3f}, {cy:.3f})")
print(f"Narrow band: X +/- {narrow_x:.3f}, Y +/- {narrow_y:.3f}")

bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(target.data)
bm.verts.ensure_lookup_table()

to_delete = []
for v in bm.verts:
    world_co = target.matrix_world @ v.co
    if world_co.z < cutoff_z:
        dist_x = abs(world_co.x - cx)
        dist_y = abs(world_co.y - cy)
        if dist_x < narrow_x and dist_y < narrow_y:
            to_delete.append(v)

print(f"Deleting {len(to_delete)} bomb vertices out of {len(bm.verts)} total")

bmesh.ops.delete(bm, geom=to_delete, context='VERTS')
bmesh.update_edit_mesh(target.data)

bpy.ops.object.mode_set(mode='OBJECT')

bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
print(f"Exported cleaned model to {output_path}")
