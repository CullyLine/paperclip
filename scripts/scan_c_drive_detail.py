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

def fmt(size_bytes):
    if size_bytes >= 1e12:
        return f"{size_bytes / 1e12:.2f} TB"
    elif size_bytes >= 1e9:
        return f"{size_bytes / 1e9:.2f} GB"
    elif size_bytes >= 1e6:
        return f"{size_bytes / 1e6:.1f} MB"
    else:
        return f"{size_bytes / 1e3:.0f} KB"

def drill(folder, min_size=100e6, label=None):
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
    print(f"\n--- {label or folder} (>{fmt(min_size)}) ---")
    for path, size in results[:25]:
        print(f"  {path:<70} {fmt(size):>12}")
    return results

# The big ones to investigate
drill(r"C:\Users\lineb\AppData\Local\Google", min_size=100e6)
drill(r"C:\Users\lineb\.paperclip", min_size=100e6)
drill(r"C:\Users\lineb\OneDrive", min_size=500e6)
drill(r"C:\Users\lineb\AI-Models", min_size=100e6)
drill(r"C:\Python\ChatBot", min_size=100e6)
drill(r"C:\Python\OmegaMario", min_size=100e6)
drill(r"C:\Python\CartPole", min_size=100e6)
drill(r"C:\Users\lineb\AppData\Local\FiveM", min_size=100e6)
drill(r"C:\Users\lineb\AppData\Local\Unity", min_size=500e6)
drill(r"C:\Users\lineb\AppData\Local\pip", min_size=500e6)
drill(r"C:\Users\lineb\AppData\Roaming\Unity", min_size=500e6)
