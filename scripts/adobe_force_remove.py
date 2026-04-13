import subprocess

# Try uninstalling with exact ARP IDs
targets = [
    ("Adobe Premiere Pro 2022", r"ARP\Machine\X86\PPRO_22_3_1"),
    ("Adobe Media Encoder 2022", r"ARP\Machine\X86\AME_22_3_1"),
    ("Adobe Creative Cloud", "Adobe.CreativeCloud"),
]

for name, pkg_id in targets:
    print(f"\n{'='*50}")
    print(f"Uninstalling {name} (id: {pkg_id})")
    print(f"{'='*50}")
    result = subprocess.run(
        ["winget", "uninstall", "--id", pkg_id, "--accept-source-agreements", "--force"],
        capture_output=True, text=True, timeout=120
    )
    # Filter progress bars
    out = "\n".join(l for l in result.stdout.split("\n") 
                     if l.strip() and not any(c in l for c in ["▒", "█", "\\", "/", "   -"]))
    print(f"  {out}")
    print(f"  Exit: {result.returncode}")

# Final check
print(f"\n{'='*50}")
print("FINAL ADOBE CHECK")
print(f"{'='*50}")
result = subprocess.run(["winget", "list"], capture_output=True, text=True)
adobe_found = []
for line in result.stdout.split("\n"):
    if "adobe" in line.lower():
        adobe_found.append(line.strip())

if adobe_found:
    print("  Still found:")
    for l in adobe_found:
        print(f"    {l}")
    print("\n  These may need the Adobe Creative Cloud Cleaner Tool to fully remove.")
    print("  Download: https://helpx.adobe.com/creative-cloud/kb/cc-cleaner-tool-installation-problems.html")
else:
    print("  All Adobe products removed!")
