import os
import sys
from pathlib import Path

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

def fmt(size_bytes):
    if size_bytes >= 1e12:
        return f"{size_bytes / 1e12:.2f} TB"
    elif size_bytes >= 1e9:
        return f"{size_bytes / 1e9:.2f} GB"
    elif size_bytes >= 1e6:
        return f"{size_bytes / 1e6:.1f} MB"
    else:
        return f"{size_bytes / 1e3:.0f} KB"

def scan_top_level(root="C:\\"):
    print(f"Scanning top-level folders in {root} ...\n")
    results = []
    try:
        for entry in os.scandir(root):
            if entry.is_dir(follow_symlinks=False):
                name = entry.name
                # Skip system-critical dirs that can't/shouldn't be moved
                skip = {"Windows", "$Recycle.Bin", "System Volume Information",
                        "PerfLogs", "Recovery", "$WinREAgent", "Config.Msi",
                        "Documents and Settings", "ProgramData"}
                if name in skip:
                    print(f"  [skip system] {name}")
                    continue
                print(f"  Scanning {name} ...")
                size = get_folder_size(entry.path)
                results.append((entry.path, size))
    except PermissionError:
        print("Permission denied on root")

    results.sort(key=lambda x: x[1], reverse=True)
    print("\n" + "=" * 60)
    print(f"{'FOLDER':<45} {'SIZE':>12}")
    print("=" * 60)
    for path, size in results:
        if size > 100e6:  # Only show folders > 100 MB
            print(f"{path:<45} {fmt(size):>12}")
    print("=" * 60)
    return results

def drill_down(folder, depth=1, min_size=500e6):
    """Show subfolders of a large folder, to find what's actually big."""
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
    if results:
        print(f"\n--- Breakdown of {folder} (folders > {fmt(min_size)}) ---")
        for path, size in results[:20]:
            print(f"  {path:<55} {fmt(size):>12}")
    return results

if __name__ == "__main__":
    top = scan_top_level("C:\\")

    # Auto-drill into the biggest folders
    print("\n\n### DETAILED BREAKDOWN OF LARGE FOLDERS ###")
    for path, size in top:
        if size > 1e9:  # Drill into anything > 1 GB
            drill_down(path, min_size=500e6)

    # Also drill into user profile specifically
    user_profile = os.path.expanduser("~")
    if os.path.exists(user_profile):
        print(f"\n\n### USER PROFILE BREAKDOWN: {user_profile} ###")
        drill_down(user_profile, min_size=200e6)

        # Common big folders in user profile
        for sub in ["AppData", "Documents", "Downloads", "Desktop", "Videos",
                     "Music", "Pictures", ".cache", ".local"]:
            subpath = os.path.join(user_profile, sub)
            if os.path.isdir(subpath):
                drill_down(subpath, min_size=200e6)

        # AppData subfolders
        for appdata_sub in ["Local", "Roaming", "LocalLow"]:
            adpath = os.path.join(user_profile, "AppData", appdata_sub)
            if os.path.isdir(adpath):
                drill_down(adpath, min_size=200e6)
