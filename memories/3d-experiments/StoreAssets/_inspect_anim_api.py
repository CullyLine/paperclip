import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath="memories/3d-experiments/StoreAssets/Samba Dancing.fbx")

for act in bpy.data.actions:
    print(f"Action: {act.name}", flush=True)
    attrs = [x for x in dir(act) if not x.startswith("_")]
    curve_attrs = [x for x in attrs if "curve" in x.lower() or "layer" in x.lower() or "slot" in x.lower() or "strip" in x.lower()]
    print(f"  relevant attrs: {curve_attrs}", flush=True)

    if hasattr(act, "fcurves"):
        try:
            print(f"  fcurves count: {len(act.fcurves)}", flush=True)
        except Exception as e:
            print(f"  fcurves error: {e}", flush=True)

    if hasattr(act, "layers"):
        for li, layer in enumerate(act.layers):
            print(f"  layer[{li}]: {layer.name}", flush=True)
            for si, strip in enumerate(layer.strips):
                print(f"    strip[{si}]: type={strip.type}", flush=True)
                if hasattr(strip, "channelbags"):
                    for ci, cb in enumerate(strip.channelbags):
                        print(f"      channelbag[{ci}]: {len(cb.fcurves)} fcurves", flush=True)
                        for fc in list(cb.fcurves)[:5]:
                            print(f"        {fc.data_path} [{fc.array_index}] keys={len(fc.keyframe_points)}", flush=True)
