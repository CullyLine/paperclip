import subprocess

result = subprocess.run(
    ["winget", "list"],
    capture_output=True, text=True
)

print("=== Adobe products installed ===")
for line in result.stdout.split("\n"):
    if "adobe" in line.lower():
        print(f"  {line.strip()}")

print("\n=== Hamachi ===")
for line in result.stdout.split("\n"):
    if "hamachi" in line.lower() or "logmein" in line.lower():
        print(f"  {line.strip()}")

print("\n=== PunkBuster ===")
for line in result.stdout.split("\n"):
    if "punk" in line.lower() or "pnkbstr" in line.lower() or "even balance" in line.lower():
        print(f"  {line.strip()}")
