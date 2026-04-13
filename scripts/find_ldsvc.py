import subprocess
import os
import glob

# Try tasklist with more detail
result = subprocess.run(
    ["tasklist", "/FI", "IMAGENAME eq LDSvc.exe", "/SVC", "/FO", "CSV"],
    capture_output=True, text=True
)
print("=== LDSvc.exe service info ===")
print(result.stdout)

# Search common locations
print("\n=== Searching for LDSvc.exe on C: ===")
for root_dir in [r"C:\Program Files", r"C:\Program Files (x86)", r"C:\Windows"]:
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for f in filenames:
            if f.lower() == "ldsvc.exe":
                full = os.path.join(dirpath, f)
                print(f"  Found: {full}")

# Also check services
result2 = subprocess.run(
    ["sc", "qc", "LDSvc"],
    capture_output=True, text=True
)
if result2.returncode == 0:
    print(f"\n=== Service config ===")
    print(result2.stdout)
