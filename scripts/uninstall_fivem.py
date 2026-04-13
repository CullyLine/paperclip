import subprocess
import shutil
import os

# Try winget first
print("=== Uninstalling FiveM ===")
result = subprocess.run(
    ["winget", "list", "--name", "FiveM"],
    capture_output=True, text=True
)
print("winget search result:")
print(result.stdout[-300:] if len(result.stdout) > 300 else result.stdout)

# Try uninstalling via winget
result2 = subprocess.run(
    ["winget", "uninstall", "--name", "FiveM", "--accept-source-agreements"],
    capture_output=True, text=True,
    timeout=60
)
print(f"\nwinget uninstall stdout: {result2.stdout[-500:]}")
print(f"winget uninstall stderr: {result2.stderr[-500:]}")
print(f"Exit code: {result2.returncode}")

# FiveM often doesn't register with winget. Kill processes and delete manually.
if result2.returncode != 0:
    print("\nwinget didn't find it. Trying manual removal...")
    
    # Kill FiveM processes
    for proc in ["FiveM.exe", "FiveM_b2699_GTAProcess.exe", "FiveM_ChromeBrowser.exe"]:
        subprocess.run(["taskkill", "/F", "/IM", proc], capture_output=True)
    
    fivem_path = os.path.expanduser(r"~\AppData\Local\FiveM")
    if os.path.exists(fivem_path):
        def get_size(path):
            total = 0
            for root, dirs, files in os.walk(path):
                for f in files:
                    try: total += os.path.getsize(os.path.join(root, f))
                    except: pass
            return total
        
        size = get_size(fivem_path)
        print(f"\nDeleting {fivem_path} ({size/1e9:.2f} GB)...")
        shutil.rmtree(fivem_path, ignore_errors=True)
        
        if os.path.exists(fivem_path):
            remaining = get_size(fivem_path)
            print(f"Partially removed. {remaining/1e9:.2f} GB still locked.")
        else:
            print(f"Done! Freed {size/1e9:.2f} GB")
    else:
        print("FiveM folder not found.")
