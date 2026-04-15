"""Generate animation via HY-Motion (Hunyuan Motion) on fal.ai.

Text prompt → skeleton animation → FBX file.
"""
import os, sys, json, urllib.request, time

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    sys.exit("Set FAL_KEY")

out_dir = os.path.dirname(os.path.abspath(__file__))

prompt = sys.argv[1] if len(sys.argv) > 1 else "A person doing the griddy dance, bouncing knees side to side with arms swinging"
duration = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
out_name = sys.argv[3] if len(sys.argv) > 3 else "StoreTungTung-griddy.fbx"

payload = json.dumps({
    "prompt": prompt,
    "duration": duration,
    "guidance_scale": 5,
    "output_format": "fbx",
}).encode()

print(f"Prompt: {prompt}", flush=True)
print(f"Duration: {duration}s", flush=True)
print("Submitting to HY-Motion...", flush=True)

req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/hunyuan-motion",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

if "fbx_file" in resp:
    fbx_url = resp["fbx_file"]["url"]
    out_path = os.path.join(out_dir, out_name)
    urllib.request.urlretrieve(fbx_url, out_path)
    print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)", flush=True)
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
            if "fbx_file" in result:
                fbx_url = result["fbx_file"]["url"]
                out_path = os.path.join(out_dir, out_name)
                urllib.request.urlretrieve(fbx_url, out_path)
                print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)", flush=True)
            if "motion_json" in result and result["motion_json"]:
                json_url = result["motion_json"]["url"]
                json_path = os.path.join(out_dir, out_name.replace(".fbx", ".json"))
                urllib.request.urlretrieve(json_url, json_path)
                print(f"Motion JSON: {json_path}", flush=True)
            print(f"Seed: {result.get('seed', '?')}", flush=True)
            break
        elif status in ("FAILED", "CANCELLED"):
            print(f"Failed: {json.dumps(sresp, indent=2)[:500]}", flush=True)
            sys.exit(1)
else:
    print(json.dumps(resp, indent=2)[:500], flush=True)
