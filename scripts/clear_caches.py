import shutil
import os
import subprocess
import time

def fmt(b):
    if b >= 1e9: return f"{b/1e9:.2f} GB"
    if b >= 1e6: return f"{b/1e6:.0f} MB"
    return f"{b/1e3:.0f} KB"

def get_size(path):
    total = 0
    try:
        for root, dirs, files in os.walk(path):
            for f in files:
                try:
                    total += os.path.getsize(os.path.join(root, f))
                except OSError:
                    pass
    except (PermissionError, OSError):
        pass
    return total

def safe_rmtree(path, label):
    if not os.path.exists(path):
        print(f"  [{label}] Not found: {path}")
        return 0
    size = get_size(path)
    print(f"  [{label}] Deleting {path} ({fmt(size)})...")
    try:
        shutil.rmtree(path, ignore_errors=True)
        if os.path.exists(path):
            remaining = get_size(path)
            freed = size - remaining
            print(f"  [{label}] Partially cleared. Freed ~{fmt(freed)}, {fmt(remaining)} locked by running processes.")
        else:
            print(f"  [{label}] Done! Freed {fmt(size)}")
        return size
    except Exception as e:
        print(f"  [{label}] Error: {e}")
        return 0

total_freed = 0

# 1. Paperclip instances
print("=" * 60)
print("1. CLEARING .paperclip INSTANCES")
print("=" * 60)
total_freed += safe_rmtree(
    os.path.expanduser(r"~\.paperclip\instances"),
    "paperclip"
)

# 2. pip cache
print("\n" + "=" * 60)
print("2. CLEARING PIP CACHE")
print("=" * 60)
result = subprocess.run(["pip", "cache", "purge"], capture_output=True, text=True)
print(f"  {result.stdout.strip()}")
if result.stderr:
    print(f"  {result.stderr.strip()}")

# 3. Temp folder
print("\n" + "=" * 60)
print("3. CLEARING TEMP FOLDER")
print("=" * 60)
temp_path = os.path.expanduser(r"~\AppData\Local\Temp")
if os.path.exists(temp_path):
    size_before = get_size(temp_path)
    count = 0
    errors = 0
    for item in os.listdir(temp_path):
        item_path = os.path.join(temp_path, item)
        try:
            if os.path.isfile(item_path):
                os.remove(item_path)
                count += 1
            elif os.path.isdir(item_path):
                shutil.rmtree(item_path, ignore_errors=True)
                count += 1
        except (PermissionError, OSError):
            errors += 1
    size_after = get_size(temp_path)
    freed = size_before - size_after
    total_freed += freed
    print(f"  Cleared {count} items, {errors} locked. Freed {fmt(freed)}")

# 4. Unity Asset Store cache
print("\n" + "=" * 60)
print("4. CLEARING UNITY ASSET STORE CACHE")
print("=" * 60)
total_freed += safe_rmtree(
    os.path.expanduser(r"~\AppData\Roaming\Unity\Asset Store-5.x"),
    "unity-assets"
)

# 5. Unity local cache
print("\n" + "=" * 60)
print("5. CLEARING UNITY LOCAL CACHE")
print("=" * 60)
total_freed += safe_rmtree(
    os.path.expanduser(r"~\AppData\Local\Unity\cache"),
    "unity-cache"
)

# 6. HuggingFace cache
print("\n" + "=" * 60)
print("6. CLEARING HUGGINGFACE CACHE")
print("=" * 60)
total_freed += safe_rmtree(
    os.path.expanduser(r"~\.cache\huggingface"),
    "huggingface"
)

# 7. VRChat cache
print("\n" + "=" * 60)
print("7. CLEARING VRCHAT CACHE")
print("=" * 60)
total_freed += safe_rmtree(
    os.path.expanduser(r"~\AppData\LocalLow\VRChat"),
    "vrchat"
)

print("\n" + "=" * 60)
print(f"TOTAL ESTIMATED FREED: {fmt(total_freed)}")
print("=" * 60)
