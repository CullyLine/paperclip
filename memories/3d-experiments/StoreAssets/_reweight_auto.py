"""Re-apply weights using Blender's automatic heat-map weighting.

Takes a rigged GLB, clears manual vertex groups, and re-assigns weights
using Blender's built-in heat diffusion (much smoother joint deformation).

Usage:
  blender --background --python _reweight_auto.py -- <input.glb> <output.glb>
"""
import bpy, sys, os

args = sys.argv[sys.argv.index("--") + 1:]
input_glb = args[0]
output_glb = args[1]

bpy.ops.wm.read_factory_settings(use_empty=True)

print("Importing model...", flush=True)
bpy.ops.import_scene.gltf(filepath=input_glb)

arm_obj = None
mesh_obj = None
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        arm_obj = obj
    elif obj.type == "MESH":
        mesh_obj = obj

print(f"Armature: {arm_obj.name}, {len(arm_obj.data.bones)} bones", flush=True)
print(f"Mesh: {mesh_obj.name}, {len(mesh_obj.data.vertices)} verts", flush=True)

# Clear existing vertex groups
mesh_obj.vertex_groups.clear()
print("Cleared old vertex groups", flush=True)

# Remove existing armature modifier
for mod in list(mesh_obj.modifiers):
    if mod.type == 'ARMATURE':
        mesh_obj.modifiers.remove(mod)

# Clear parent but keep transform
mesh_obj.parent = None

# Select mesh, then armature (parent must be active)
bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj

# Parent with automatic weights (heat diffusion)
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
print("Applied automatic weights (heat diffusion)", flush=True)

# Check coverage
total = len(mesh_obj.data.vertices)
weighted = sum(1 for v in mesh_obj.data.vertices if len(v.groups) > 0)
print(f"Weight coverage: {weighted}/{total} ({weighted/max(total,1)*100:.1f}%)", flush=True)

# List vertex groups created
for vg in mesh_obj.vertex_groups:
    print(f"  Group: {vg.name}", flush=True)

bpy.ops.export_scene.gltf(filepath=output_glb, export_format='GLB')
size_kb = os.path.getsize(output_glb) // 1024
print(f"Exported: {output_glb} ({size_kb} KB)", flush=True)
