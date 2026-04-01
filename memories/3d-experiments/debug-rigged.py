"""Debug what's inside a rigged GLB after import."""
import bpy
import sys

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])

print("\n=== All objects ===")
for obj in bpy.context.scene.objects:
    print(f"  {obj.name} (type={obj.type})")
    if obj.type == 'MESH':
        m = obj.data
        print(f"    Mesh: {m.name}, {len(m.vertices)} verts, {len(m.polygons)} faces")
        print(f"    Vertex groups: {len(obj.vertex_groups)}")
        for vg in obj.vertex_groups:
            print(f"      - {vg.name}")
        # Check for armature modifier
        for mod in obj.modifiers:
            print(f"    Modifier: {mod.name} (type={mod.type})")
        # Check parent
        if obj.parent:
            print(f"    Parent: {obj.parent.name} (type={obj.parent.type})")
    elif obj.type == 'ARMATURE':
        print(f"    Bones: {len(obj.data.bones)}")
        for b in obj.data.bones:
            print(f"      - {b.name}")
