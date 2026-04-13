import os, urllib.request, json, base64

FAL_KEY = os.environ.get("FAL_KEY", "").strip()
if not FAL_KEY:
    exit("Set FAL_KEY")

out_dir = os.path.dirname(os.path.abspath(__file__))
ref = os.path.join(out_dir, "StoreTungTung-club-masked.png")

with open(ref, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()

payload = json.dumps({
    "image_url": "data:image/png;base64," + b64,
    "prompt": "Complete this wooden baseball bat showing the full object. Extend and fill in the missing handle and grip area. Show the entire bat from the knob at the bottom of the handle to the barrel at the top. Center the complete bat vertically on a pure white background. Keep the exact same wood color, grain texture, and style.",
    "guidance_scale": 4.0,
    "safety_tolerance": "5"
}).encode()

print("Completing bat via FLUX.1 Kontext...")
req = urllib.request.Request(
    "https://queue.fal.run/fal-ai/flux-pro/kontext",
    data=payload, method="POST",
    headers={"Authorization": "Key " + FAL_KEY, "Content-Type": "application/json"},
)
resp = json.loads(urllib.request.urlopen(req).read().decode())

if "images" in resp and resp["images"]:
    img_url = resp["images"][0]["url"]
    out_path = os.path.join(out_dir, "StoreTungTung-club-complete.png")
    urllib.request.urlretrieve(img_url, out_path)
    print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)")
elif "request_id" in resp:
    rid = resp["request_id"]
    print(f"Queued: {rid}")
    status_url = resp.get("status_url", "")
    response_url = resp.get("response_url", "")
    print(f"Status: {status_url}")

    with open(os.path.join(out_dir, "club-complete-submit.json"), "w") as f:
        json.dump(resp, f, indent=2)

    import time
    for i in range(30):
        time.sleep(5)
        sreq = urllib.request.Request(status_url, headers={"Authorization": "Key " + FAL_KEY})
        sresp = json.loads(urllib.request.urlopen(sreq).read().decode())
        print(f"  [{i*5}s] {sresp.get('status', '?')}")
        if sresp.get("status") == "COMPLETED":
            rreq = urllib.request.Request(response_url, headers={"Authorization": "Key " + FAL_KEY})
            result = json.loads(urllib.request.urlopen(rreq).read().decode())
            if "images" in result and result["images"]:
                img_url = result["images"][0]["url"]
                out_path = os.path.join(out_dir, "StoreTungTung-club-complete.png")
                urllib.request.urlretrieve(img_url, out_path)
                print(f"Saved: {out_path} ({os.path.getsize(out_path) // 1024} KB)")
            break
