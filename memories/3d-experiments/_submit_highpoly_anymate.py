"""Submit highpoly GLBs to Anymate for comparison with lowpoly results."""
import os, shutil, time
from gradio_client import Client, handle_file

DIR = os.path.dirname(os.path.abspath(__file__))

pets = [
    ("cappuccino", "cappuccino-highpoly.glb"),
    ("tungtung", "tungtung-highpoly.glb"),
    ("tralalero", "tralalero-highpoly.glb"),
]

for pet_name, filename in pets:
    glb = os.path.join(DIR, filename)
    out_blend = os.path.join(DIR, f"{pet_name}-anymate-hp.blend")

    if not os.path.exists(glb):
        print(f"[SKIP] {glb} not found")
        continue
    if os.path.exists(out_blend):
        print(f"[SKIP] {out_blend} already exists")
        continue

    print(f"\n{'='*60}")
    print(f"Submitting {pet_name} highpoly to Anymate...")
    print(f"  Input: {glb} ({os.path.getsize(glb) / 1024:.0f} KB)")

    t0 = time.time()
    client = Client("yfdeng/Anymate")

    print("  Step 1/4: Uploading mesh...")
    client.predict(mesh_file=handle_file(glb), api_name="/process_input")

    print("  Step 2/4: Running joint prediction...")
    client.predict(eps=0.03, min_samples=1, api_name="/get_all_results")

    print("  Step 3/4: Building visualization...")
    vis_result = client.predict(api_name="/vis_all")

    print("  Step 4/4: Exporting .blend...")
    blend_result = client.predict(api_name="/prepare_blender_file")

    elapsed = time.time() - t0
    print(f"  Done in {elapsed:.1f}s")

    if blend_result and os.path.exists(blend_result):
        shutil.copy2(blend_result, out_blend)
        print(f"  Saved: {out_blend}")

    if vis_result and isinstance(vis_result, tuple) and vis_result[0]:
        vis_out = os.path.join(DIR, f"{pet_name}-anymate-hp-vis.glb")
        if os.path.exists(vis_result[0]):
            shutil.copy2(vis_result[0], vis_out)
            print(f"  Saved: {vis_out}")

print("\nDone!")
