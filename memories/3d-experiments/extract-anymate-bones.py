"""Extract bone data from Anymate .blend files for comparison with UniRig.

Usage: blender --background --python extract-anymate-bones.py -- <file.blend> [file2.blend ...]

Outputs bone table to stdout and JSON sidecar for each armature.
"""
import bpy, sys, json, os


def calc_max_depth(armature_data):
    def depth(bone):
        if not bone.children:
            return 1
        return 1 + max(depth(c) for c in bone.children)

    roots = [b for b in armature_data.bones if b.parent is None]
    if not roots:
        return 0
    return max(depth(r) for r in roots)


argv = sys.argv
argv = argv[argv.index("--") + 1:]

for blend_path in argv:
    print(f"\n{'='*60}")
    print(f"Loading: {blend_path}")
    bpy.ops.wm.open_mainfile(filepath=blend_path)

    armatures = [obj for obj in bpy.data.objects if obj.type == 'ARMATURE']

    if not armatures:
        print("  No armatures found!")
        continue

    for obj in armatures:
        arm = obj.data
        bones = []
        for bone in arm.bones:
            h = bone.head_local
            t = bone.tail_local
            bones.append({
                "name": bone.name,
                "head": [round(h.x, 4), round(h.y, 4), round(h.z, 4)],
                "tail": [round(t.x, 4), round(t.y, 4), round(t.z, 4)],
                "parent": bone.parent.name if bone.parent else None,
                "children": [c.name for c in bone.children],
                "length": round(bone.length, 4)
            })

        max_d = calc_max_depth(arm)

        summary = {
            "file": blend_path,
            "armature": obj.name,
            "bone_count": len(bones),
            "bones": bones,
            "root_bones": [b["name"] for b in bones if b["parent"] is None],
            "leaf_bones": [b["name"] for b in bones if not b["children"]],
            "max_depth": max_d
        }

        print(f"\nArmature: {obj.name} ({len(bones)} bones)")
        print(f"  Roots: {summary['root_bones']}")
        print(f"  Leaves: {summary['leaf_bones']}")
        print(f"  Max chain depth: {max_d}")
        print(f"\n  {'Name':<25} {'Parent':<25} {'Children':<30} {'Length'}")
        print(f"  {'-'*100}")
        for b in bones:
            children_str = ', '.join(b['children']) or '(leaf)'
            parent_str = b['parent'] or '(root)'
            print(f"  {b['name']:<25} {parent_str:<25} {children_str:<30} {b['length']:.4f}")

        json_out = os.path.splitext(blend_path)[0] + "-bones.json"
        with open(json_out, 'w') as f:
            json.dump(summary, f, indent=2)
        print(f"\n  JSON written: {json_out}")
