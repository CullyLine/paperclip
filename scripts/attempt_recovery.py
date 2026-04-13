import subprocess
import os

# Check if Windows has Volume Shadow Copies
print("=== Checking for Volume Shadow Copies ===")
result = subprocess.run(["vssadmin", "list", "shadows"], capture_output=True, text=True)
print(result.stdout if result.stdout.strip() else "  No shadow copies found.")
if result.stderr:
    print(f"  {result.stderr.strip()}")

# Check if Windows File History has a backup
print("\n=== Checking File History backups ===")
file_history_path = os.path.expanduser(r"~\AppData\Local\Microsoft\Windows\FileHistory")
if os.path.exists(file_history_path):
    print(f"  File History folder exists at {file_history_path}")
    for item in os.listdir(file_history_path):
        print(f"    {item}")
else:
    print("  File History not configured.")

# Check if the .paperclip folder still has anything
print("\n=== Current .paperclip state ===")
paperclip_path = os.path.expanduser(r"~\.paperclip")
if os.path.exists(paperclip_path):
    for root, dirs, files in os.walk(paperclip_path):
        for f in files:
            full = os.path.join(root, f)
            try:
                size = os.path.getsize(full)
                print(f"  {full} ({size} bytes)")
            except:
                pass
    if not any(os.scandir(paperclip_path)):
        print("  Empty.")
else:
    print("  .paperclip folder is gone entirely.")

# Check Windows Previous Versions on the folder
print("\n=== Checking for 'Previous Versions' of .paperclip ===")
result2 = subprocess.run(
    ["wmic", "shadowcopy", "list", "brief"],
    capture_output=True, text=True
)
if "No Instance" in result2.stdout or not result2.stdout.strip():
    print("  No shadow copies available for recovery.")
else:
    print(result2.stdout[:500])
