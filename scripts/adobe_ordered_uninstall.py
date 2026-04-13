import subprocess

def uninstall(name, pkg_id):
    print(f"\n{'='*50}")
    print(f"Uninstalling {name}")
    print(f"{'='*50}")
    
    # Kill any Adobe processes first
    for proc in ["Adobe CEF Helper.exe", "Adobe Desktop Service.exe",
                  "Creative Cloud.exe", "Creative Cloud Helper.exe",
                  "CoreSync.exe", "AdobeIPCBroker.exe",
                  "AdobeNotificationClient.exe", "AdobeUpdateService.exe",
                  "CCXProcess.exe", "CCLibrary.exe"]:
        subprocess.run(["taskkill", "/F", "/IM", proc], capture_output=True)
    
    result = subprocess.run(
        ["winget", "uninstall", "--id", pkg_id, "--accept-source-agreements", "--force"],
        capture_output=True, text=True, timeout=180
    )
    out_lines = [l for l in result.stdout.split("\n")
                 if l.strip() and not any(c in l for c in ["▒", "█"])]
    print("\n".join(f"  {l}" for l in out_lines if l.strip()))
    print(f"  Exit: {result.returncode}")
    return result.returncode

# Step 1: Media Encoder first
uninstall("Adobe Media Encoder 2022", r"ARP\Machine\X86\AME_22_3_1")

# Step 2: Creative Cloud last
uninstall("Adobe Creative Cloud", "Adobe.CreativeCloud")

# Verify
print(f"\n{'='*50}")
print("VERIFICATION")
print(f"{'='*50}")
result = subprocess.run(["winget", "list"], capture_output=True, text=True)
for line in result.stdout.split("\n"):
    if "adobe" in line.lower():
        print(f"  {line.strip()}")
