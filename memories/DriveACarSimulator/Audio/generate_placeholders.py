"""Generate 40 silent OGG placeholder files for Drive a Car Simulator audio tree."""
import subprocess, os

BASE = os.path.dirname(os.path.abspath(__file__))

AUDIO_FILES = {
    "engines": [
        ("buggy_idle.ogg", 4),
        ("sedan_idle.ogg", 5),
        ("racer_idle.ogg", 5),
        ("supercar_idle.ogg", 6),
    ],
    "ui": [
        ("click.ogg", 0.1),
        ("purchase_success.ogg", 1),
        ("purchase_fail.ogg", 0.4),
        ("tab_switch.ogg", 0.2),
        ("panel_open.ogg", 0.3),
        ("panel_close.ogg", 0.25),
        ("notification.ogg", 0.3),
        ("level_up.ogg", 1.5),
    ],
    "hatch": [
        ("common.ogg", 0.8),
        ("uncommon.ogg", 1),
        ("rare.ogg", 1.5),
        ("epic.ogg", 2.5),
        ("legendary.ogg", 4),
        ("mythic.ogg", 5.5),
    ],
    "rebirth": [
        ("riser.ogg", 1.5),
        ("whoosh.ogg", 0.6),
        ("boom.ogg", 0.35),
        ("confetti.ogg", 2),
    ],
    "music": [
        ("grasslands.ogg", 30),
        ("desert.ogg", 30),
        ("frozen.ogg", 30),
        ("neon.ogg", 30),
    ],
    "ambient": [
        ("grasslands_amb.ogg", 15),
        ("desert_amb.ogg", 15),
        ("frozen_amb.ogg", 15),
        ("neon_amb.ogg", 15),
    ],
    "driving": [
        ("screech.ogg", 0.8),
        ("boost.ogg", 1),
        ("collision.ogg", 0.5),
        ("coin_pickup.ogg", 0.3),
        ("distance_marker.ogg", 0.4),
        ("lap_horn.ogg", 1.2),
    ],
    "fuel": [
        ("warning_25.ogg", 0.1),
        ("warning_10.ogg", 0.15),
        ("warning_5.ogg", 0.6),
        ("empty_stall.ogg", 1.5),
    ],
}

total = 0
for folder, files in AUDIO_FILES.items():
    dir_path = os.path.join(BASE, folder)
    os.makedirs(dir_path, exist_ok=True)
    for filename, duration in files:
        out = os.path.join(dir_path, filename)
        subprocess.run([
            "ffmpeg", "-y", "-f", "lavfi", "-i",
            f"anullsrc=r=44100:cl=mono",
            "-t", str(duration),
            "-c:a", "libvorbis", "-q:a", "2",
            out
        ], capture_output=True)
        if os.path.exists(out):
            size = os.path.getsize(out)
            print(f"  OK  {folder}/{filename} ({size} bytes)")
            total += 1
        else:
            print(f"FAIL  {folder}/{filename}")

print(f"\nGenerated {total}/40 placeholder OGG files.")
