import shutil

total, used, free = shutil.disk_usage("C:\\")
print(f"C: Drive")
print(f"  Total: {total/1e9:.1f} GB")
print(f"  Used:  {used/1e9:.1f} GB")
print(f"  Free:  {free/1e9:.1f} GB")
print(f"\n  Before: 30 GB free")
print(f"  Now:    {free/1e9:.1f} GB free")
print(f"  Gained: {free/1e9 - 30:.1f} GB")
