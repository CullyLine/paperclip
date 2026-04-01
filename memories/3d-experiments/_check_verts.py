import json

for pet in ['cappuccino', 'tungtung', 'tralalero']:
    path = rf'F:\CODE STUFF\Paperclip\memories\3d-experiments\{pet}-rig-comparison.json'
    with open(path) as f:
        d = json.load(f)
    a = d['anymate']
    u = d['unirig']
    print(f"{pet}:")
    print(f"  Anymate: {a['total_verts']} total verts, {a['weighted_verts']} weighted ({a['weight_coverage']}%)")
    print(f"  UniRig:  {u['total_verts']} total verts, {u['weighted_verts']} weighted ({u['weight_coverage']}%)")
    print()
