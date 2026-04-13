import os

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

def fmt(b):
    if b >= 1e9: return f"{b/1e9:.2f} GB"
    if b >= 1e6: return f"{b/1e6:.0f} MB"
    return f"{b/1e3:.0f} KB"

def drill(folder, min_size=500e6, label=None):
    results = []
    try:
        for entry in os.scandir(folder):
            if entry.is_dir(follow_symlinks=False):
                size = get_folder_size(entry.path)
                if size > min_size:
                    results.append((entry.path, size))
    except (PermissionError, OSError):
        pass
    results.sort(key=lambda x: x[1], reverse=True)
    print(f"\n{'='*70}")
    print(f" {label or folder}")
    print(f"{'='*70}")
    for path, size in results[:25]:
        print(f"  {path:<60} {fmt(size):>10}")

# User profile breakdown
drill(r"C:\Users\lineb", min_size=500e6, label="USER PROFILE (>500 MB)")

# AppData breakdown
drill(r"C:\Users\lineb\AppData\Local", min_size=500e6, label="AppData\\Local (>500 MB)")
drill(r"C:\Users\lineb\AppData\Roaming", min_size=500e6, label="AppData\\Roaming (>500 MB)")
drill(r"C:\Users\lineb\AppData\LocalLow", min_size=500e6, label="AppData\\LocalLow (>500 MB)")

# ProgramData (35 GB is a lot)
drill(r"C:\ProgramData", min_size=500e6, label="ProgramData (>500 MB)")

# Drill into paperclip instances
drill(r"C:\Users\lineb\.paperclip\instances", min_size=100e6, label=".paperclip\\instances (>100 MB)")

# Check pagefile and hibernation
print(f"\n{'='*70}")
print(" SYSTEM FILES")
print(f"{'='*70}")
for f in ["pagefile.sys", "hiberfil.sys", "swapfile.sys"]:
    fp = os.path.join("C:\\", f)
    try:
        size = os.path.getsize(fp)
        print(f"  {fp:<60} {fmt(size):>10}")
    except OSError:
        print(f"  {fp:<60} {'(no access)':>10}")
