"""Compare Anymate vs UniRig bone data side-by-side.

Usage: blender --background --python compare-rigs.py -- <anymate.blend> <unirig.glb> <pet-name>

Outputs a comparison report to stdout and saves JSON.
"""
import bpy, sys, json, os

argv = sys.argv
argv = argv[argv.index("--") + 1:]

anymate_path = argv[0]
unirig_path = argv[1]
pet_name = argv[2]

DIR = os.path.dirname(os.path.abspath(anymate_path))


def analyze_rig(filepath, is_blend=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)

    if is_blend:
        bpy.ops.wm.open_mainfile(filepath=filepath)
    else:
        bpy.ops.import_scene.gltf(filepath=filepath)

    armatures = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']

    if not armatures:
        return {"error": "no armature found", "bone_count": 0}

    arm_obj = armatures[0]
    arm = arm_obj.data

    def calc_depth(bone):
        if not bone.children:
            return 1
        return 1 + max(calc_depth(c) for c in bone.children)

    roots = [b for b in arm.bones if b.parent is None]
    max_depth = max(calc_depth(r) for r in roots) if roots else 0

    total_verts = 0
    weighted_verts = 0
    for mesh_obj in meshes:
        mesh = mesh_obj.data
        total_verts += len(mesh.vertices)
        for v in mesh.vertices:
            if len(v.groups) > 0:
                weighted_verts += 1

    bones = []
    for bone in arm.bones:
        bones.append({
            "name": bone.name,
            "parent": bone.parent.name if bone.parent else None,
            "children_count": len(bone.children),
            "length": round(bone.length, 4),
        })

    return {
        "bone_count": len(arm.bones),
        "root_count": len(roots),
        "root_names": [r.name for r in roots],
        "leaf_count": sum(1 for b in arm.bones if not b.children),
        "max_chain_depth": max_depth,
        "total_verts": total_verts,
        "weighted_verts": weighted_verts,
        "weight_coverage": round(weighted_verts / max(total_verts, 1) * 100, 1),
        "bones": bones,
    }


print(f"\n{'='*70}")
print(f"  RIG COMPARISON: {pet_name}")
print(f"{'='*70}")

print(f"\nAnalyzing Anymate: {anymate_path}")
anymate = analyze_rig(anymate_path, is_blend=True)

print(f"Analyzing UniRig:  {unirig_path}")
unirig = analyze_rig(unirig_path, is_blend=False)

print(f"\n{'Metric':<30} {'Anymate':>12} {'UniRig':>12} {'Winner':>10}")
print("-" * 70)

def compare(label, a_val, u_val, higher_better=True):
    if a_val == u_val:
        winner = "TIE"
    elif (a_val > u_val) == higher_better:
        winner = "Anymate"
    else:
        winner = "UniRig"
    print(f"{label:<30} {str(a_val):>12} {str(u_val):>12} {winner:>10}")
    return winner

winners = []
winners.append(compare("Bone count", anymate["bone_count"], unirig["bone_count"]))
winners.append(compare("Root bones", anymate["root_count"], unirig["root_count"], higher_better=False))
winners.append(compare("Leaf bones", anymate["leaf_count"], unirig["leaf_count"]))
winners.append(compare("Max chain depth", anymate["max_chain_depth"], unirig["max_chain_depth"]))
winners.append(compare("Weight coverage %", anymate["weight_coverage"], unirig["weight_coverage"]))
winners.append(compare("Weighted vertices", anymate["weighted_verts"], unirig["weighted_verts"]))

anymate_wins = winners.count("Anymate")
unirig_wins = winners.count("UniRig")
ties = winners.count("TIE")

print(f"\n{'='*70}")
print(f"  SCORE: Anymate {anymate_wins} — UniRig {unirig_wins} — Ties {ties}")
print(f"{'='*70}")

report = {
    "pet": pet_name,
    "anymate": anymate,
    "unirig": unirig,
    "score": {"anymate": anymate_wins, "unirig": unirig_wins, "ties": ties}
}

out = os.path.join(DIR, f"{pet_name}-rig-comparison.json")
with open(out, 'w') as f:
    json.dump(report, f, indent=2)
print(f"\nFull report: {out}")
