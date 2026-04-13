"""Inspect all bone positions, parents, and spatial data for cleanup planning."""
import bpy
import sys
from mathutils import Vector

sys.stdout.reconfigure(line_buffering=True)

argv = sys.argv
argv = argv[argv.index("--") + 1:]
input_path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=input_path)

armature = None
mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        mesh_obj = obj

if not armature:
    print("ERROR: No armature")
    sys.exit(1)

verts = [mesh_obj.matrix_world @ v.co for v in mesh_obj.data.vertices] if mesh_obj else []
if verts:
    mesh_min_z = min(v.z for v in verts)
    mesh_max_z = max(v.z for v in verts)
    mesh_height = mesh_max_z - mesh_min_z
    mesh_center_x = (min(v.x for v in verts) + max(v.x for v in verts)) / 2
    print(f"Mesh height: {mesh_height:.3f}, center_x: {mesh_center_x:.3f}")
    print(f"Mesh Z range: [{mesh_min_z:.3f}, {mesh_max_z:.3f}]")

bpy.ops.object.select_all(action='DESELECT')
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='EDIT')

print(f"\n{'Name':<25} {'Parent':<25} {'Head XYZ':<35} {'Tail XYZ':<35} {'Len':>6} {'H%':>5} {'Side':>5}")
print("-" * 160)

for eb in sorted(armature.data.edit_bones, key=lambda b: (b.head.z, b.head.x)):
    parent_name = eb.parent.name if eb.parent else "ROOT"
    head = eb.head
    tail = eb.tail
    length = eb.length
    height_pct = (head.z - mesh_min_z) / max(mesh_height, 0.001) * 100 if verts else 0
    
    side = "C"
    if head.x > mesh_center_x + 0.03:
        side = "R"
    elif head.x < mesh_center_x - 0.03:
        side = "L"
    
    print(f"{eb.name:<25} {parent_name:<25} ({head.x:>7.3f}, {head.y:>7.3f}, {head.z:>7.3f})   ({tail.x:>7.3f}, {tail.y:>7.3f}, {tail.z:>7.3f})   {length:>6.3f} {height_pct:>5.1f} {side:>5}", flush=True)

print(f"\nTotal: {len(armature.data.edit_bones)} bones")

print("\n\n=== BONE TREE ===")
def print_tree(bone, indent=0):
    h = bone.head
    side = "C"
    if h.x > mesh_center_x + 0.03: side = "R"
    elif h.x < mesh_center_x - 0.03: side = "L"
    height_pct = (h.z - mesh_min_z) / max(mesh_height, 0.001) * 100 if verts else 0
    print(f"{'  ' * indent}{bone.name} [{side}] z={h.z:.3f} ({height_pct:.0f}%) len={bone.length:.3f}", flush=True)
    for child in sorted(bone.children, key=lambda c: c.head.x):
        print_tree(child, indent + 1)

roots = [b for b in armature.data.edit_bones if b.parent is None]
for r in roots:
    print_tree(r)

bpy.ops.object.mode_set(mode='OBJECT')
