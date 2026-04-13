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

def drill(folder, min_size=1e6, depth=0, max_depth=3):
    results = []
    try:
        for entry in os.scandir(folder):
            if entry.is_dir(follow_symlinks=False):
                size = get_folder_size(entry.path)
                results.append((entry.path, size))
            elif entry.is_file(follow_symlinks=False):
                try:
                    size = entry.stat(follow_symlinks=False).st_size
                    if size > min_size:
                        results.append((entry.path, size))
                except (PermissionError, OSError):
                    pass
    except (PermissionError, OSError):
        pass

    results.sort(key=lambda x: x[1], reverse=True)
    indent = "  " * depth
    for path, size in results:
        if size > min_size:
            is_dir = os.path.isdir(path)
            marker = "[DIR] " if is_dir else "[FILE]"
            print(f"{indent}{marker} {os.path.basename(path):<60} {fmt(size):>12}")
            if is_dir and depth < max_depth and size > 100e6:
                drill(path, min_size=min_size, depth=depth + 1, max_depth=max_depth)

root = r"C:\Users\lineb\AppData\Local\Google\Play Games"
print(f"=== Contents of {root} ===\n")
drill(root, min_size=10e6, max_depth=4)
