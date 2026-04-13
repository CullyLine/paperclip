import os
import shutil
import subprocess

# Check actual free space
print("=== C: Drive Space ===")
total, used, free = shutil.disk_usage("C:\\")
print(f"Total: {total / 1e9:.1f} GB")
print(f"Used:  {used / 1e9:.1f} GB")
print(f"Free:  {free / 1e9:.1f} GB")

# Double check the Google folder
print("\n=== Google Play Games folder check ===")
gpg = r"C:\Users\lineb\AppData\Local\Google\Play Games"
print(f"Exists: {os.path.exists(gpg)}")
google_dir = r"C:\Users\lineb\AppData\Local\Google"
if os.path.exists(google_dir):
    for entry in os.scandir(google_dir):
        print(f"  {entry.name} (dir={entry.is_dir()})")

# Check Recycle Bin size - it's at C:\$Recycle.Bin
print("\n=== Recycle Bin check ===")
recycle_path = r"C:\$Recycle.Bin"
total_recycle = 0
try:
    for root, dirs, files in os.walk(recycle_path):
        for f in files:
            try:
                total_recycle += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
except PermissionError:
    print("  (Permission denied reading recycle bin directly)")

print(f"  Recycle bin estimated size: {total_recycle / 1e9:.2f} GB")
print("\n  Tip: If large, empty it via 'Clear-RecycleBin' or right-click on desktop.")

# Re-scan top level to see what's actually eating space now
print("\n=== Top space consumers on C: (>5 GB) ===")
def get_folder_size(path):
    total = 0
    try:
        for entry in os.scandir(path):
            try:
                if entry.is_file(follow_symlinks=False):
                    total += entry.stat(follow_symlinks=False).st_size
                elif entry.is_dir(follow_symlinks=False):
                    total += get_folder_size(entry.path)
            except (PermissionError, OSError):
                pass
    except (PermissionError, OSError):
        pass
    return total

results = []
for entry in os.scandir("C:\\"):
    if entry.is_dir(follow_symlinks=False):
        try:
            size = get_folder_size(entry.path)
            if size > 5e9:
                results.append((entry.path, size))
        except:
            pass

results.sort(key=lambda x: x[1], reverse=True)
accounted = 0
for path, size in results:
    print(f"  {path:<45} {size/1e9:.1f} GB")
    accounted += size
print(f"\n  Accounted: {accounted/1e9:.1f} GB")
print(f"  Total used: {used/1e9:.1f} GB")
print(f"  Unaccounted (system/pagefile/hiberfil/etc): {(used - accounted)/1e9:.1f} GB")
