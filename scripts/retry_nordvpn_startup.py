import subprocess

# Try with exact service names (sc needs exact names)
print("=== Finding NordVPN services ===")
result = subprocess.run(["sc", "query", "type=", "service", "state=", "all"], capture_output=True, text=True)
nord_services = []
lines = result.stdout.split("\n")
for i, line in enumerate(lines):
    if "nord" in line.lower():
        print(f"  {line.strip()}")
        # Extract service name
        if "SERVICE_NAME" in line:
            svc_name = line.split(":")[1].strip()
            nord_services.append(svc_name)

print(f"\nFound services: {nord_services}")
for svc in nord_services:
    r = subprocess.run(["sc", "config", svc, "start=", "demand"], capture_output=True, text=True)
    if r.returncode == 0:
        print(f"  Set '{svc}' to manual start (disabled auto-start)")
    else:
        print(f"  Failed for '{svc}': {r.stderr.strip()}")

# Also disable from registry startup
print("\n=== Checking startup registry for NordVPN ===")
for key in [
    r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run",
    r"HKLM\Software\Microsoft\Windows\CurrentVersion\Run",
]:
    r = subprocess.run(["reg", "query", key], capture_output=True, text=True)
    for line in r.stdout.split("\n"):
        if "nord" in line.lower():
            print(f"  Found: {line.strip()}")
            val_name = line.strip().split("    ")[0]
            subprocess.run(["reg", "delete", key, "/v", val_name, "/f"], capture_output=True)
            print(f"  Removed '{val_name}' from startup")

# Also check Adobe Premiere/Media Encoder were cleaned
print("\n=== Verifying Adobe removal ===")
result2 = subprocess.run(["winget", "list"], capture_output=True, text=True)
adobe_found = False
for line in result2.stdout.split("\n"):
    if "adobe" in line.lower():
        print(f"  Still installed: {line.strip()}")
        adobe_found = True
if not adobe_found:
    print("  All Adobe products removed!")
