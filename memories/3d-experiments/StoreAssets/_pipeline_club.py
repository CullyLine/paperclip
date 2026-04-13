"""Full pipeline for Tung Tung's bat/club: Hunyuan3D → Decimate → Polish → GLB

No rigging - just a simple prop asset.
Target: 100-200 faces.
"""
import os, sys, json, urllib.request, base64, time

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

out_dir = os.path.dirname(os.path.abspath(__file__))
ref_image = os.path.join(out_dir, "StoreTungTung-club-gen-2.png")

with open(ref_image, "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()

print("=== STEP 1: Submit to Hunyuan3D v3 ===", flush=True)
payload = json.dumps({
    "input_image_url": "data:image/png;base64," + img_b64,
}).encode()

req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/hunyuan3d-v3/image-to-3d",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

if "model_glb" in resp:
    glb_url = resp["model_glb"]["url"]
    hp_path = os.path.join(out_dir, "StoreTungTung-club-highpoly.glb")
    urllib.request.urlretrieve(glb_url, hp_path)
    print(f"Direct result: {hp_path} ({os.path.getsize(hp_path) // 1024} KB)", flush=True)
elif "request_id" in resp:
    rid = resp["request_id"]
    status_url = resp.get("status_url", "")
    response_url = resp.get("response_url", "")
    print(f"Queued: {rid}", flush=True)

    for i in range(60):
        time.sleep(5)
        sreq = urllib.request.Request(status_url, headers={"Authorization": "Key " + FAL_KEY})
        sresp = json.loads(urllib.request.urlopen(sreq).read().decode())
        status = sresp.get("status", "?")
        print(f"  [{i*5}s] {status}", flush=True)
        if status == "COMPLETED":
            rreq = urllib.request.Request(response_url, headers={"Authorization": "Key " + FAL_KEY})
            result = json.loads(urllib.request.urlopen(rreq).read().decode())
            glb_url = None
            for key in ["model_glb", "model_mesh", "mesh"]:
                if key in result and result[key]:
                    obj = result[key]
                    glb_url = obj.get("url") if isinstance(obj, dict) else obj
                    break
            if glb_url:
                hp_path = os.path.join(out_dir, "StoreTungTung-club-highpoly.glb")
                urllib.request.urlretrieve(glb_url, hp_path)
                print(f"Downloaded: {hp_path} ({os.path.getsize(hp_path) // 1024} KB)", flush=True)
            else:
                print("No GLB found in response:", json.dumps(result, indent=2)[:500], flush=True)
            break
        elif status in ("FAILED", "CANCELLED"):
            print(f"Failed: {json.dumps(sresp, indent=2)[:500]}", flush=True)
            sys.exit(1)
else:
    print(json.dumps(resp, indent=2)[:500], flush=True)
    sys.exit(1)

print("\n=== Highpoly done. Run Blender decimate next. ===", flush=True)
