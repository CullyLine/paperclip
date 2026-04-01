"""Restore Blender user preferences and startup from backup.

Copies backed-up userpref.blend and startup.blend to Blender's config directory.
Works for any Blender version — pass the version as an argument (default: 5.1).

Usage:
  python restore-blender-prefs.py          # restores to Blender 5.1
  python restore-blender-prefs.py 5.2      # restores to Blender 5.2
"""
import shutil
import os
import sys

version = sys.argv[1] if len(sys.argv) > 1 else "5.1"
backup_dir = os.path.dirname(os.path.abspath(__file__))
config_dir = os.path.join(
    os.environ["APPDATA"], "Blender Foundation", "Blender", version, "config"
)

os.makedirs(config_dir, exist_ok=True)

for filename in ["userpref.blend", "startup.blend"]:
    src = os.path.join(backup_dir, filename)
    dst = os.path.join(config_dir, filename)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"Restored: {dst}")
    else:
        print(f"Skipped (not in backup): {filename}")

print(f"\nDone! Restart Blender to apply.")
