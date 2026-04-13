"""Quick poly count check for both models."""
import bpy, os, sys

out_dir = r"F:\CODE STUFF\Paperclip\memories\3d-experiments\StoreAssets"
files = {
    "Tung Tung Sahur": os.path.join(out_dir, "StoreTungTung-tpose-FINAL.glb"),
    "Bat/Club": os.path.join(out_dir, "StoreTungTung-club.glb"),
}

for label, path in files.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not os.path.isfile(path):
        print(f"{label}: FILE NOT FOUND ({path})")
        continue
    bpy.ops.import_scene.gltf(filepath=path)
    total_faces = 0
    total_tris = 0
    total_verts = 0
    has_armature = False
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            total_faces += len(obj.data.polygons)
            total_verts += len(obj.data.vertices)
            for poly in obj.data.polygons:
                if len(poly.vertices) == 3:
                    total_tris += 1
                elif len(poly.vertices) == 4:
                    total_tris += 2
                else:
                    total_tris += len(poly.vertices) - 2
        elif obj.type == 'ARMATURE':
            has_armature = True
    size_kb = os.path.getsize(path) // 1024
    print(f"{label}: {total_faces} faces, {total_tris} tris, {total_verts} verts, {size_kb} KB, armature={'yes' if has_armature else 'no'}")

print("---")
