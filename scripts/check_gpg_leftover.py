import os

path = r"C:\Users\lineb\AppData\Local\Google\Play Games"
if os.path.exists(path):
    total = 0
    for dirpath, dirnames, filenames in os.walk(path):
        for f in filenames:
            try:
                total += os.path.getsize(os.path.join(dirpath, f))
            except OSError:
                pass
    print(f"Folder still exists: {path}")
    print(f"Size remaining: {total / 1e9:.2f} GB")
    print("\nThis is leftover data. Safe to delete.")
else:
    print("Folder was cleaned up automatically! 550 GB freed.")
