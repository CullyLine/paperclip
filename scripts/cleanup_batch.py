import subprocess
import shutil
import os

def run(cmd, label, timeout=120):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        out = result.stdout.strip()
        err = result.stderr.strip()
        # Filter out winget progress bars
        out_lines = [l for l in out.split("\n") if not any(c in l for c in ["▒", "█", "\\", "/"])]
        filtered = "\n".join(l for l in out_lines if l.strip())
        if filtered:
            print(f"  {filtered}")
        if err and "successfully" not in err.lower():
            print(f"  stderr: {err[:200]}")
        print(f"  Exit code: {result.returncode}")
        return result.returncode
    except subprocess.TimeoutExpired:
        print(f"  Timed out after {timeout}s")
        return -1

# ============================================================
# 1. KILL ADOBE PROCESSES
# ============================================================
print("\n" + "#"*60)
print("# STEP 1: KILL ALL ADOBE PROCESSES")
print("#"*60)
adobe_procs = [
    "Creative Cloud.exe", "Creative Cloud Helper.exe",
    "Adobe CEF Helper.exe", "Adobe Desktop Service.exe",
    "CoreSync.exe", "AdobeIPCBroker.exe",
    "AdobeNotificationClient.exe", "AdobeUpdateService.exe",
    "CCXProcess.exe", "CCLibrary.exe", "node.exe"
]
for proc in adobe_procs:
    subprocess.run(["taskkill", "/F", "/IM", proc], capture_output=True)
print("  Killed Adobe processes.")

# 2. UNINSTALL ADOBE PRODUCTS VIA WINGET
print("\n" + "#"*60)
print("# STEP 2: UNINSTALL ADOBE PRODUCTS")
print("#"*60)

adobe_ids = [
    ("Adobe Premiere Pro 2022", "PPRO_22_3_1"),
    ("Adobe Media Encoder 2022", "AME_22_3_1"),
    ("Adobe Creative Cloud", "Adobe.CreativeCloud"),
]

# Uninstall via winget
run(["winget", "uninstall", "--id", "Adobe.CreativeCloud", "--accept-source-agreements", "--silent"],
    "Uninstalling Adobe Creative Cloud")

# ARP-based uninstalls
for name, arp_id in [("Premiere Pro", "PPRO_22_3_1"), ("Media Encoder", "AME_22_3_1")]:
    run(["winget", "uninstall", "--name", name, "--accept-source-agreements", "--silent"],
        f"Uninstalling Adobe {name}")

# Notification client (MSIX)
run(["winget", "uninstall", "--name", "Adobe Notification Client", "--accept-source-agreements", "--silent"],
    "Uninstalling Adobe Notification Client")

# ============================================================
# 3. CLEAN UP ADOBE LEFTOVER FOLDERS
# ============================================================
print("\n" + "#"*60)
print("# STEP 3: CLEAN UP ADOBE LEFTOVERS")
print("#"*60)
adobe_dirs = [
    os.path.expanduser(r"~\AppData\Roaming\Adobe"),
    os.path.expanduser(r"~\AppData\Local\Adobe"),
    r"C:\Program Files\Adobe",
    r"C:\Program Files (x86)\Adobe",
    r"C:\ProgramData\Adobe",
]
for d in adobe_dirs:
    if os.path.exists(d):
        def get_size(path):
            total = 0
            for root, dirs, files in os.walk(path):
                for f in files:
                    try: total += os.path.getsize(os.path.join(root, f))
                    except: pass
            return total
        size = get_size(d)
        print(f"  Deleting {d} ({size/1e6:.0f} MB)...")
        shutil.rmtree(d, ignore_errors=True)
        if os.path.exists(d):
            print(f"    Partially removed (some files locked)")
        else:
            print(f"    Done!")
    else:
        print(f"  {d} - not found (already clean)")

# ============================================================
# 4. CLOSE NORDVPN + DISABLE FROM STARTUP
# ============================================================
print("\n" + "#"*60)
print("# STEP 4: CLOSE NORDVPN + DISABLE STARTUP")
print("#"*60)
subprocess.run(["taskkill", "/F", "/IM", "nordvpn-service.exe"], capture_output=True)
subprocess.run(["taskkill", "/F", "/IM", "NordUpdateService.exe"], capture_output=True)
subprocess.run(["taskkill", "/F", "/IM", "NordVPN.exe"], capture_output=True)
print("  Killed NordVPN processes.")

# Disable NordVPN services from auto-start
for svc in ["NordVPN Service", "NordUpdater"]:
    r = subprocess.run(["sc", "config", svc, "start=", "demand"], capture_output=True, text=True)
    if r.returncode == 0:
        print(f"  Disabled auto-start for: {svc}")
    else:
        print(f"  Could not disable {svc}: {r.stderr.strip()}")

# ============================================================
# 5. UNINSTALL HAMACHI
# ============================================================
print("\n" + "#"*60)
print("# STEP 5: UNINSTALL HAMACHI")
print("#"*60)
subprocess.run(["taskkill", "/F", "/IM", "hamachi-2.exe"], capture_output=True)
run(["winget", "uninstall", "--id", "LogMeIn.Hamachi", "--accept-source-agreements", "--silent"],
    "Uninstalling Hamachi")

# ============================================================
# 6. DISABLE PHONEEXPERIENCEHOST
# ============================================================
print("\n" + "#"*60)
print("# STEP 6: DISABLE PHONEEXPERIENCEHOST (Your Phone)")
print("#"*60)
subprocess.run(["taskkill", "/F", "/IM", "PhoneExperienceHost.exe"], capture_output=True)
print("  Killed PhoneExperienceHost.")
# Disable via startup task
r = subprocess.run(
    ["reg", "add", r"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
     "/v", "PhoneLink", "/t", "REG_BINARY", "/d", "0300000000000000000000000000", "/f"],
    capture_output=True, text=True
)
print(f"  Startup registry: {'disabled' if r.returncode == 0 else r.stderr.strip()}")

# ============================================================
# 7. UNINSTALL PUNKBUSTER
# ============================================================
print("\n" + "#"*60)
print("# STEP 7: UNINSTALL PUNKBUSTER")
print("#"*60)
subprocess.run(["taskkill", "/F", "/IM", "PnkBstrA.exe"], capture_output=True)
subprocess.run(["taskkill", "/F", "/IM", "PnkBstrB.exe"], capture_output=True)
# Stop and delete the service
subprocess.run(["sc", "stop", "PnkBstrA"], capture_output=True)
subprocess.run(["sc", "delete", "PnkBstrA"], capture_output=True, text=True)
subprocess.run(["sc", "stop", "PnkBstrB"], capture_output=True)
subprocess.run(["sc", "delete", "PnkBstrB"], capture_output=True, text=True)
# Remove PunkBuster folder
pb_paths = [
    r"C:\Windows\SysWOW64\PnkBstrA.exe",
    r"C:\Windows\SysWOW64\PnkBstrB.exe",
]
for p in pb_paths:
    if os.path.exists(p):
        try:
            os.remove(p)
            print(f"  Deleted {p}")
        except OSError as e:
            print(f"  Could not delete {p}: {e}")
print("  PunkBuster removed.")

# ============================================================
# 8. DISABLE OPERA BROWSER_ASSISTANT
# ============================================================
print("\n" + "#"*60)
print("# STEP 8: DISABLE OPERA BROWSER_ASSISTANT")
print("#"*60)
subprocess.run(["taskkill", "/F", "/IM", "browser_assistant.exe"], capture_output=True)
# It auto-starts via a scheduled task or startup entry
r = subprocess.run(
    ["reg", "delete", r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run",
     "/v", "Opera Browser Assistant", "/f"],
    capture_output=True, text=True
)
if r.returncode == 0:
    print("  Disabled Opera Browser Assistant from startup.")
else:
    print(f"  Registry entry not found or already removed. You can also disable it in Opera Settings > Advanced > Browser Assistant.")

print("\n" + "#"*60)
print("# ALL DONE!")
print("#"*60)
