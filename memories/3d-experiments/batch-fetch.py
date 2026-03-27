"""Poll all Hunyuan3D jobs from batch-tracker.json until complete, then download GLBs."""
import os, json, urllib.request, sys, time

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

HERE = os.path.dirname(os.path.abspath(__file__))
TRACKER = os.path.join(HERE, "batch-tracker.json")
MODEL_BASE = "fal-ai/hunyuan3d-v3"

with open(TRACKER) as f:
    tracker = json.load(f)

pending = {name: info for name, info in tracker.items()
           if info.get("submitted") and not info.get("downloaded")}

print(f"{len(pending)} jobs to fetch, polling...")

while pending:
    for name in list(pending.keys()):
        info = pending[name]
        rid = info["request_id"]
        url = f"https://queue.fal.run/{MODEL_BASE}/requests/{rid}/status"
        req = urllib.request.Request(url, headers={"Authorization": "Key " + FAL_KEY})

        try:
            raw = urllib.request.urlopen(req).read().decode()
            status_resp = json.loads(raw)
            status = status_resp.get("status", "UNKNOWN")
        except urllib.error.HTTPError as e:
            print(f"  [{name}] HTTP {e.code}")
            continue

        if status == "COMPLETED":
            print(f"  [{name}] COMPLETED - downloading...")
            result_url = f"https://queue.fal.run/{MODEL_BASE}/requests/{rid}"
            req2 = urllib.request.Request(result_url, headers={"Authorization": "Key " + FAL_KEY})
            resp = json.loads(urllib.request.urlopen(req2).read().decode())

            glb_url = None
            for key in ("model_glb", "model_mesh", "glb", "mesh"):
                val = resp.get(key)
                if isinstance(val, dict) and val.get("url"):
                    glb_url = val["url"]
                    break
            if not glb_url:
                for key, val in resp.items():
                    if isinstance(val, dict) and "url" in val and key != "logs":
                        glb_url = val["url"]
                        break

            if glb_url:
                out_path = os.path.join(HERE, f"{name}-highpoly.glb")
                urllib.request.urlretrieve(glb_url, out_path)
                size_mb = os.path.getsize(out_path) / (1024 * 1024)
                print(f"  [{name}] Saved {out_path} ({size_mb:.1f} MB)")
                tracker[name]["downloaded"] = True
                tracker[name]["highpoly_path"] = out_path
            else:
                print(f"  [{name}] COMPLETED but no GLB URL found")
                tracker[name]["downloaded"] = False

            del pending[name]
            with open(TRACKER, "w") as f:
                json.dump(tracker, f, indent=2)

        elif status in ("FAILED", "CANCELLED"):
            print(f"  [{name}] {status}")
            del pending[name]
            tracker[name]["downloaded"] = False
            with open(TRACKER, "w") as f:
                json.dump(tracker, f, indent=2)
        else:
            logs = status_resp.get("logs", [])
            last_log = logs[-1]["message"] if logs else ""
            print(f"  [{name}] {status} {last_log[:60]}")

    if pending:
        print(f"\n--- {len(pending)} still processing, waiting 30s... ---\n")
        time.sleep(30)

print("\n=== All done ===")
for name, info in tracker.items():
    dl = "YES" if info.get("downloaded") else "NO"
    print(f"  {name}: downloaded={dl}")
