"""Submit GLB models to Anymate (HuggingFace Spaces) for auto-rigging.

Usage: python submit-anymate.py <pet-name> [pet-name2 ...]
Example: python submit-anymate.py cappuccino tungtung tralalero

Outputs: <pet>-anymate.blend and <pet>-anymate-vis.glb for each pet.

Anymate is a multi-step Gradio app:
  1. /process_input  — upload mesh, run initial processing
  2. /get_all_results — DBSCAN joint clustering (eps=0.03, min_samples=1)
  3. /vis_all         — build visualization mesh with bones
  4. /prepare_blender_file — export .blend with armature + skinning
"""
import sys, os, shutil, time

DIR = os.path.dirname(os.path.abspath(__file__))


def submit_pet(pet_name):
    from gradio_client import Client, handle_file

    glb = os.path.join(DIR, f"{pet_name}-game-340.glb")
    if not os.path.exists(glb):
        print(f"[SKIP] {glb} not found")
        return False

    out_blend = os.path.join(DIR, f"{pet_name}-anymate.blend")
    if os.path.exists(out_blend):
        print(f"[SKIP] {out_blend} already exists — delete to re-run")
        return True

    print(f"\n{'='*60}")
    print(f"Submitting {pet_name} to Anymate...")
    print(f"  Input: {glb}")
    print(f"{'='*60}")

    t0 = time.time()
    hf_token = os.environ.get("HF_TOKEN")
    client = Client("yfdeng/Anymate", token=hf_token)

    print("  Step 1/4: Uploading mesh...")
    client.predict(
        mesh_file=handle_file(glb),
        api_name="/process_input"
    )

    print("  Step 2/4: Running joint prediction...")
    client.predict(eps=0.03, min_samples=1, api_name="/get_all_results")

    print("  Step 3/4: Building visualization...")
    vis_result = client.predict(api_name="/vis_all")

    print("  Step 4/4: Exporting .blend...")
    blend_result = client.predict(api_name="/prepare_blender_file")

    elapsed = time.time() - t0
    print(f"  Anymate completed in {elapsed:.1f}s")

    ok = False

    if blend_result and os.path.exists(blend_result):
        shutil.copy2(blend_result, out_blend)
        print(f"  Saved: {out_blend}")
        ok = True

    if vis_result and isinstance(vis_result, tuple) and vis_result[0]:
        vis_path = vis_result[0]
        if os.path.exists(vis_path):
            vis_out = os.path.join(DIR, f"{pet_name}-anymate-vis.glb")
            shutil.copy2(vis_path, vis_out)
            print(f"  Saved: {vis_out}")

    return ok


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python submit-anymate.py <pet-name> [pet-name2 ...]")
        print("Example: python submit-anymate.py cappuccino tungtung tralalero")
        sys.exit(1)

    pets = sys.argv[1:]
    results = {}

    for pet in pets:
        try:
            ok = submit_pet(pet)
            results[pet] = "OK" if ok else "FAIL"
        except Exception as e:
            print(f"  ERROR: {e}")
            results[pet] = f"ERROR: {e}"

    print(f"\n{'='*60}")
    print("Results:")
    for pet, status in results.items():
        print(f"  {pet}: {status}")
