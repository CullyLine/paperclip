#!/usr/bin/env python3
"""
Desert pet batch: Hunyuan3D v3 -> highpoly GLB -> decimate (~340) -> polish.
Stops BEFORE rigging (no Anymate).

Requires: FAL_KEY, Blender on disk.

Usage:
  python pipeline_desert_pets_to_polish.py           # full run (resume-safe)
  python pipeline_desert_pets_to_polish.py --submit-only
  python pipeline_desert_pets_to_polish.py --fetch-only
  python pipeline_desert_pets_to_polish.py --decimate-polish-only
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


def urlopen_json(req: urllib.request.Request, timeout: int = 120, retries: int = 5) -> dict:
    """GET/POST and parse JSON; retry on 502/503/504 and timeouts."""
    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code in (502, 503, 504) and attempt < retries - 1:
                time.sleep(min(15 + attempt * 10, 120))
                continue
            raise
        except OSError as e:
            last_err = e
            if attempt < retries - 1:
                time.sleep(min(10 + attempt * 8, 90))
                continue
            raise
    raise last_err  # type: ignore[misc]


REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DECIMATE_SCRIPT = os.path.join(REPO_ROOT, "decimate.py")
POLISH_SCRIPT = os.path.join(HERE, "polish-pet.py")
TRACKER_PATH = os.path.join(HERE, "desert-pets-pipeline-tracker.json")
MODEL = "fal-ai/hunyuan3d-v3/image-to-3d"
MODEL_BASE = "fal-ai/hunyuan3d-v3"

PETS: list[tuple[str, str]] = [
    ("fennec-fox", "pet-fennec-fox-concept.png"),
    ("sand-cat-cub", "pet-sand-cat-cub-concept.png"),
    ("mummy-cat", "pet-mummy-cat-concept.png"),
    ("king-black-dragon", "pet-king-black-dragon-concept.png"),
    ("gecko-grin", "pet-gecko-grin-concept.png"),
    ("celestial-camel", "pet-celestial-camel-concept.png"),
]

TARGET_FACES = 340
VOXEL_SIZE = 0.032


def find_assets_dir() -> str:
    env = os.environ.get("PAPERCLIP_CONCEPT_ASSETS", "").strip()
    candidates = [
        env,
        r"C:\Users\lineb\.cursor\projects\f-CODE-STUFF-Paperclip\assets",
        os.path.join(REPO_ROOT, "assets"),
    ]
    for c in candidates:
        if not c or not os.path.isdir(c):
            continue
        test = os.path.join(c, "pet-fennec-fox-concept.png")
        if os.path.isfile(test):
            return c
    sys.exit(
        "Could not find concept PNGs. Set PAPERCLIP_CONCEPT_ASSETS to the folder "
        "containing pet-*-concept.png files."
    )


def find_blender() -> str:
    for path in (
        r"F:\SteamLibrary\steamapps\common\Blender\blender.exe",
        r"F:\CODE STUFF\tools\blender-5.0.1-windows-x64\blender.exe",
        os.path.join(REPO_ROOT, "tools", "blender-5.0.1-windows-x64", "blender.exe"),
    ):
        if os.path.isfile(path):
            return path
    sys.exit("Blender not found. Install Blender or edit find_blender() in pipeline_desert_pets_to_polish.py")


def load_tracker() -> dict:
    if os.path.isfile(TRACKER_PATH):
        with open(TRACKER_PATH, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_tracker(t: dict) -> None:
    with open(TRACKER_PATH, "w", encoding="utf-8") as f:
        json.dump(t, f, indent=2)


def fal_headers() -> dict:
    key = os.environ.get("FAL_KEY", "").strip()
    if not key:
        sys.exit("Set FAL_KEY in the environment.")
    return {"Authorization": "Key " + key, "Content-Type": "application/json"}


def submit_all(assets_dir: str, tracker: dict) -> None:
    headers = fal_headers()
    url = "https://queue.fal.run/" + MODEL
    for slug, png in PETS:
        if tracker.get(slug, {}).get("request_id"):
            print(f"[SKIP submit] {slug}: already has request_id")
            continue
        img_path = os.path.join(assets_dir, png)
        if not os.path.isfile(img_path):
            print(f"[ERR] missing {img_path}")
            tracker[slug] = {"error": "missing_image", "image": png}
            save_tracker(tracker)
            continue
        with open(img_path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        payload = json.dumps({"input_image_url": "data:image/png;base64," + b64}).encode()
        req = urllib.request.Request(url, data=payload, method="POST", headers=headers)
        try:
            resp = json.loads(urllib.request.urlopen(req, timeout=120).read().decode())
            rid = resp.get("request_id", "")
            tracker[slug] = {
                "request_id": rid,
                "status_url": resp.get("status_url", ""),
                "image": png,
                "submitted": True,
            }
            print(f"[OK submit] {slug}: {rid}")
        except Exception as e:
            print(f"[ERR submit] {slug}: {e}")
            tracker[slug] = {"error": str(e), "submitted": False}
        save_tracker(tracker)
        time.sleep(1.5)


def poll_and_download(tracker: dict) -> None:
    headers_fal = {"Authorization": fal_headers()["Authorization"]}
    pending = {
        slug: tracker[slug]
        for slug, _ in PETS
        if tracker.get(slug, {}).get("request_id") and not tracker[slug].get("downloaded")
    }
    if not pending:
        print("Nothing to fetch (all downloaded or no request_ids).")
        return

    print(f"Polling {len(pending)} jobs...")
    while pending:
        for slug in list(pending.keys()):
            info = pending[slug]
            rid = info["request_id"]
            st_url = f"https://queue.fal.run/{MODEL_BASE}/requests/{rid}/status"
            req = urllib.request.Request(st_url, headers=headers_fal)
            try:
                status_resp = urlopen_json(req, timeout=90, retries=4)
                status = status_resp.get("status", "UNKNOWN")
            except urllib.error.HTTPError as e:
                print(f"  [{slug}] status HTTP {e.code}")
                continue

            if status == "COMPLETED":
                result_url = f"https://queue.fal.run/{MODEL_BASE}/requests/{rid}"
                req2 = urllib.request.Request(result_url, headers=headers_fal)
                resp = urlopen_json(req2, timeout=300, retries=20)
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
                    out_path = os.path.join(HERE, f"{slug}-highpoly.glb")
                    for dl_try in range(5):
                        try:
                            urllib.request.urlretrieve(glb_url, out_path)
                            break
                        except Exception as e:
                            if dl_try < 4:
                                print(f"  [{slug}] download retry ({e})...")
                                time.sleep(5 + dl_try * 5)
                            else:
                                raise
                    mb = os.path.getsize(out_path) / (1024 * 1024)
                    print(f"  [{slug}] saved {out_path} ({mb:.1f} MB)")
                    tracker[slug]["downloaded"] = True
                    tracker[slug]["highpoly_path"] = out_path
                else:
                    print(f"  [{slug}] COMPLETED but no GLB URL: keys={list(resp.keys())}")
                    tracker[slug]["downloaded"] = False
                del pending[slug]
                save_tracker(tracker)
            elif status in ("FAILED", "CANCELLED"):
                print(f"  [{slug}] {status}")
                tracker[slug]["downloaded"] = False
                tracker[slug]["failed_status"] = status
                del pending[slug]
                save_tracker(tracker)
            else:
                logs = status_resp.get("logs", [])
                tail = logs[-1]["message"] if logs else ""
                print(f"  [{slug}] {status} {tail[:70]}")

        if pending:
            print(f"\n--- {len(pending)} still running, sleep 30s ---\n")
            time.sleep(30)


def decimate_and_polish(blender: str, tracker: dict) -> None:
    for slug, _ in PETS:
        hp = os.path.join(HERE, f"{slug}-highpoly.glb")
        game = os.path.join(HERE, f"{slug}-game-340.glb")
        if not os.path.isfile(hp):
            print(f"[SKIP decimate] {slug}: no highpoly")
            continue
        if tracker.get(slug, {}).get("decimated") and os.path.isfile(game):
            print(f"[SKIP decimate] {slug}: already decimated")
        else:
            print(f"\n[DECIMATE] {slug}")
            cmd = [
                blender,
                "--background",
                "--python",
                DECIMATE_SCRIPT,
                "--",
                hp,
                game,
                str(TARGET_FACES),
                str(VOXEL_SIZE),
            ]
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=600, encoding="utf-8", errors="replace")
            if not os.path.isfile(game):
                print(f"[FAIL decimate] {slug}")
                print(r.stdout[-2000:] if r.stdout else "")
                print(r.stderr[-1000:] if r.stderr else "")
                tracker.setdefault(slug, {})["decimated"] = False
                save_tracker(tracker)
                continue
            tracker.setdefault(slug, {})["decimated"] = True
            tracker[slug]["game_path"] = game
            save_tracker(tracker)
            print(f"[OK decimate] {slug} ({os.path.getsize(game) // 1024} KB)")

        if tracker.get(slug, {}).get("polished") and os.path.isfile(game):
            print(f"[SKIP polish] {slug}: already polished")
            continue
        print(f"[POLISH] {slug}")
        cmd2 = [
            blender,
            "--background",
            "--python",
            POLISH_SCRIPT,
            "--",
            game,
            game,
        ]
        r2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=300, encoding="utf-8", errors="replace")
        if r2.returncode != 0 and not os.path.isfile(game):
            print(f"[WARN polish] {slug} rc={r2.returncode}")
            print(r2.stderr[-800:] if r2.stderr else "")
        tracker.setdefault(slug, {})["polished"] = True
        save_tracker(tracker)
        print(f"[OK polish] {slug}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--submit-only", action="store_true")
    ap.add_argument("--fetch-only", action="store_true")
    ap.add_argument("--decimate-polish-only", action="store_true")
    args = ap.parse_args()

    assets = find_assets_dir()
    blender = find_blender()
    tracker = load_tracker()

    print(f"Assets: {assets}")
    print(f"Blender: {blender}")
    print(f"Tracker: {TRACKER_PATH}\n")

    if args.decimate_polish_only:
        decimate_and_polish(blender, tracker)
        return

    if not args.fetch_only:
        submit_all(assets, tracker)
        tracker = load_tracker()

    if not args.submit_only:
        poll_and_download(tracker)
        tracker = load_tracker()
        decimate_and_polish(blender, tracker)

    print("\n=== Done (rigging not run) ===")
    for slug, _ in PETS:
        g = os.path.join(HERE, f"{slug}-game-340.glb")
        ok = os.path.isfile(g)
        print(f"  {slug}: game-340={'YES' if ok else 'NO'}")


if __name__ == "__main__":
    main()
