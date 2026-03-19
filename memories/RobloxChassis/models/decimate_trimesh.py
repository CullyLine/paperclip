#!/usr/bin/env python3
"""
Decimate GLB models using trimesh + pyfqmr for low-poly Roblox assets.
Preserves vertex colors and texture coordinates where possible.

Usage: python decimate_trimesh.py <input.glb> <output.glb> [target_faces]
"""
import sys
import trimesh
import numpy as np

def decimate_scene(input_path, output_path, target_faces=2000):
    scene = trimesh.load(input_path)

    if isinstance(scene, trimesh.Scene):
        meshes = [g for g in scene.geometry.values() if isinstance(g, trimesh.Trimesh)]
    elif isinstance(scene, trimesh.Trimesh):
        meshes = [scene]
    else:
        print(f"Unexpected type: {type(scene)}")
        return

    total_input = sum(len(m.faces) for m in meshes)
    print(f"Input: {len(meshes)} mesh(es), {total_input} total faces")

    if total_input <= target_faces:
        print("Already below target, copying as-is")
        with open(input_path, 'rb') as f:
            data = f.read()
        with open(output_path, 'wb') as f:
            f.write(data)
        return

    try:
        import pyfqmr
        use_fqmr = True
        print("Using pyfqmr for quadric mesh simplification")
    except ImportError:
        use_fqmr = False
        print("pyfqmr not available, using trimesh simplify")

    decimated_meshes = []
    for i, mesh in enumerate(meshes):
        face_count = len(mesh.faces)
        mesh_ratio = face_count / total_input
        mesh_target = max(int(target_faces * mesh_ratio), 100)

        print(f"  Mesh {i}: {face_count} faces -> target {mesh_target}")

        if face_count <= mesh_target:
            decimated_meshes.append(mesh)
            continue

        if use_fqmr:
            simplifier = pyfqmr.Simplify()
            simplifier.setMesh(mesh.vertices, mesh.faces)
            simplifier.simplify_mesh(
                target_count=mesh_target,
                aggressiveness=10,
                preserve_border=False,
                verbose=True
            )
            new_verts, new_faces, _ = simplifier.getMesh()
            new_mesh = trimesh.Trimesh(vertices=new_verts, faces=new_faces)
            if mesh.visual and hasattr(mesh.visual, 'vertex_colors') and mesh.visual.vertex_colors is not None:
                try:
                    from scipy.spatial import cKDTree
                    tree = cKDTree(mesh.vertices)
                    _, indices = tree.query(new_verts)
                    new_mesh.visual.vertex_colors = mesh.visual.vertex_colors[indices]
                except Exception:
                    pass
        else:
            ratio = mesh_target / face_count
            new_mesh = mesh.simplify_quadric_decimation(face_count=mesh_target)

        print(f"    Result: {len(new_mesh.faces)} faces")
        decimated_meshes.append(new_mesh)

    if len(decimated_meshes) == 1:
        result = decimated_meshes[0]
    else:
        result = trimesh.Scene(decimated_meshes)

    total_output = sum(len(m.faces) for m in decimated_meshes)
    print(f"Output: {total_output} total faces")

    result.export(output_path, file_type='glb')
    print(f"Exported to {output_path}")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python decimate_trimesh.py <input.glb> <output.glb> [target_faces]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    target = int(sys.argv[3]) if len(sys.argv) > 3 else 2000

    decimate_scene(input_path, output_path, target)
