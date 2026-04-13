"""Re-merge existing armature onto a new game mesh.

Extracts the armature from an already-rigged GLB and transfers it
to a new (properly decimated) game mesh. Bypasses Anymate entirely.

Usage: blender --background --python _remerge_armature.py -- <old_rigged.glb> <new_game.glb> <output.glb>
"""
import bpy
import sys
import os
from mathutils import Vector

sys.stdout.reconfigure(line_buffering=True)

argv = sys.argv
argv = argv[argv.index("--") + 1:]
old_rigged = argv[0]
new_game = argv[1]
output_path = argv[2]

print("=== Re-merge Armature ===", flush=True)
print(f"Old rigged: {old_rigged}", flush=True)
print(f"New game mesh: {new_game}", flush=True)
print(f"Output: {output_path}", flush=True)

print("\n[1/5] Loading old rigged model...", flush=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=old_rigged)

armature = None
old_mesh = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        old_mesh = obj

if not armature:
    print("ERROR: No armature found in old rigged model")
    sys.exit(1)

print(f"  Armature: {armature.name} ({len(armature.data.bones)} bones)", flush=True)
if old_mesh:
    print(f"  Old mesh: {old_mesh.name} ({len(old_mesh.data.vertices)} verts)", flush=True)

print("\n[2/5] Loading new game mesh...", flush=True)
bpy.ops.import_scene.gltf(filepath=new_game)

new_mesh = None
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj != old_mesh:
        new_mesh = obj

if not new_mesh:
    print("ERROR: Could not find new game mesh")
    sys.exit(1)

print(f"  New mesh: {new_mesh.name} ({len(new_mesh.data.vertices)} verts, {len(new_mesh.data.polygons)} faces)", flush=True)


def get_bbox(obj):
    wm = obj.matrix_world
    verts = [wm @ Vector(c) for c in obj.bound_box]
    xs = [v.x for v in verts]
    ys = [v.y for v in verts]
    zs = [v.z for v in verts]
    mn = Vector((min(xs), min(ys), min(zs)))
    mx = Vector((max(xs), max(ys), max(zs)))
    return (mn + mx) / 2, mx - mn


print("\n[3/5] Aligning armature to new mesh...", flush=True)
if old_mesh:
    a_center, a_size = get_bbox(old_mesh)
else:
    a_center, a_size = get_bbox(armature)
g_center, g_size = get_bbox(new_mesh)

scale_factors = []
for i in range(3):
    if a_size[i] > 0.001:
        scale_factors.append(g_size[i] / a_size[i])
scale = sum(scale_factors) / len(scale_factors) if scale_factors else 1.0

if abs(scale - 1.0) > 0.01:
    armature.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    print(f"  Scaled armature by {scale:.4f}", flush=True)
else:
    print(f"  Scale ~1.0, no adjustment needed", flush=True)

print("\n[4/5] Parenting + weight transfer...", flush=True)
if old_mesh:
    bpy.data.objects.remove(old_mesh, do_unlink=True)

new_mesh.parent = armature
mod = new_mesh.modifiers.new(name='Armature', type='ARMATURE')
mod.object = armature

bone_data = []
bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')
for ebone in armature.data.edit_bones:
    bone_data.append((ebone.name, ebone.head.copy(), ebone.tail.copy()))
bpy.ops.object.mode_set(mode='OBJECT')

for bname, _, _ in bone_data:
    if bname not in new_mesh.vertex_groups:
        new_mesh.vertex_groups.new(name=bname)

for v in new_mesh.data.vertices:
    v_pos = new_mesh.matrix_world @ v.co
    best_bone = None
    best_dist = float('inf')
    for bname, bhead, btail in bone_data:
        mid = (bhead + btail) / 2
        for pt in [bhead, btail, mid]:
            d = (v_pos - pt).length
            if d < best_dist:
                best_dist = d
                best_bone = bname
    if best_bone:
        vg = new_mesh.vertex_groups.get(best_bone)
        if vg:
            vg.add([v.index], 1.0, 'REPLACE')

total = len(new_mesh.data.vertices)
weighted = sum(1 for v in new_mesh.data.vertices if len(v.groups) > 0)
print(f"  Weight transfer: {weighted}/{total} ({weighted/max(total,1)*100:.1f}%)", flush=True)

print("\n[5/5] Exporting...", flush=True)
bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
size_kb = os.path.getsize(output_path) // 1024
print(f"  Exported: {output_path} ({size_kb} KB)", flush=True)
print(f"  Bones: {len(armature.data.bones)}", flush=True)
print(f"  Faces: {len(new_mesh.data.polygons)}", flush=True)
print("\nDone!", flush=True)
