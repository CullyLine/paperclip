import subprocess

# Find where LDSvc.exe is running from
result = subprocess.run(
    ["wmic", "process", "where", "name='LDSvc.exe'", "get", "ProcessId,ExecutablePath,CommandLine", "/FORMAT:LIST"],
    capture_output=True, text=True
)
print("=== LDSvc.exe Details ===")
print(result.stdout)

# Also check what winget knows
result2 = subprocess.run(
    ["winget", "list"],
    capture_output=True, text=True
)
# Search for anything that could be LD
for line in result2.stdout.split("\n"):
    if any(x in line.lower() for x in ["ldsvc", "logmein", "logi", "lucid"]):
        print(f"  winget: {line.strip()}")
