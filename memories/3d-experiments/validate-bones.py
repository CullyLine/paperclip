"""Validate bone coverage on a rigged GLB by checking if key mesh regions have bones nearby.

Analyzes the mesh bounding box and vertex distribution to identify regions
that might be missing bone coverage (e.g. wing tips, fins, extremities).

Usage: blender --background --python validate-bones.py -- <rigged.glb>
"""
import bpy
import sys
from mathutils import Vector

argv = sys.argv
argv = argv[argv.index("--") + 1:]
glb_path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

armature = None
mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        mesh_obj = obj

if not armature or not mesh_obj:
    print("ERROR: Need both armature and mesh")
    sys.exit(1)

# Collect all bone head/tail positions
bone_positions = []
for bone in armature.data.bones:
    bone_positions.append(bone.head_local)
    bone_positions.append(bone.tail_local)

# Analyze mesh vertex distribution
mesh = mesh_obj.data
vertices = [mesh_obj.matrix_world @ v.co for v in mesh.vertices]

# Find mesh bounding box
min_pos = Vector((min(v.x for v in vertices), min(v.y for v in vertices), min(v.z for v in vertices)))
max_pos = Vector((max(v.x for v in vertices), max(v.y for v in vertices), max(v.z for v in vertices)))
size = max_pos - min_pos

print(f"\nMesh: {len(vertices)} vertices")
print(f"Bounds: ({min_pos.x:.3f},{min_pos.y:.3f},{min_pos.z:.3f}) to ({max_pos.x:.3f},{max_pos.y:.3f},{max_pos.z:.3f})")
print(f"Size: {size.x:.3f} x {size.y:.3f} x {size.z:.3f}")
print(f"\nArmature: {len(armature.data.bones)} bones")

# Divide mesh into spatial regions and check bone coverage
GRID = 4
region_size = size / GRID
uncovered = []

for ix in range(GRID):
    for iy in range(GRID):
        for iz in range(GRID):
            region_min = min_pos + Vector((ix, iy, iz)) * region_size
            region_max = region_min + region_size

            # Count vertices in this region
            verts_in_region = sum(1 for v in vertices
                if region_min.x <= v.x <= region_max.x
                and region_min.y <= v.y <= region_max.y
                and region_min.z <= v.z <= region_max.z)

            if verts_in_region < 3:
                continue

            # Check if any bone is near this region
            region_center = (region_min + region_max) / 2
            min_dist = min((bp - region_center).length for bp in bone_positions)

            coverage = "OK" if min_dist < region_size.length else "UNCOVERED"
            if coverage == "UNCOVERED":
                uncovered.append((region_center, verts_in_region, min_dist))

# Check vertex groups for unweighted vertices
unweighted = 0
for v in mesh.vertices:
    if len(v.groups) == 0:
        unweighted += 1

print(f"\nVertex weight coverage: {len(vertices) - unweighted}/{len(vertices)} weighted ({unweighted} unweighted)")

if uncovered:
    print(f"\nWARNING: {len(uncovered)} mesh regions may need bones:")
    for center, count, dist in sorted(uncovered, key=lambda x: -x[1]):
        print(f"  Region at ({center.x:+.3f},{center.y:+.3f},{center.z:+.3f}): "
              f"{count} verts, nearest bone {dist:.3f} away")
else:
    print("\nAll mesh regions have bone coverage!")

# Print bone hierarchy summary
print(f"\nBone hierarchy:")
for bone in armature.data.bones:
    parent = bone.parent.name if bone.parent else "(root)"
    children = len(bone.children)
    leaf = " [LEAF]" if children == 0 else ""
    print(f"  {bone.name}: parent={parent}, {children} children{leaf}")
