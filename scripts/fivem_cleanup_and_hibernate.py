import os
import shutil
import subprocess

def fmt(b):
    if b >= 1e9: return f"{b/1e9:.2f} GB"
    if b >= 1e6: return f"{b/1e6:.0f} MB"
    return f"{b/1e3:.0f} KB"

def get_size(path):
    total = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            try: total += os.path.getsize(os.path.join(root, f))
            except: pass
    return total

# Check FiveM leftover
fivem_path = os.path.expanduser(r"~\AppData\Local\FiveM")
if os.path.exists(fivem_path):
    size = get_size(fivem_path)
    print(f"FiveM leftover data: {fmt(size)}")
    print("Deleting...")
    shutil.rmtree(fivem_path, ignore_errors=True)
    if not os.path.exists(fivem_path):
        print(f"Cleaned! Freed {fmt(size)}")
    else:
        print(f"Some files locked. Remaining: {fmt(get_size(fivem_path))}")
else:
    print("FiveM data already cleaned up by uninstaller.")

# Disable hibernation (requires admin, but let's try)
print("\n=== Disabling Hibernation ===")
print("This requires admin privileges...")
result = subprocess.run(
    ["powercfg", "/hibernate", "off"],
    capture_output=True, text=True
)
if result.returncode == 0:
    print("Hibernation disabled! hiberfil.sys (~13.7 GB) will be freed.")
else:
    print(f"Failed (may need admin): {result.stderr.strip()}")
    print("You can run this manually in an admin terminal: powercfg /hibernate off")
