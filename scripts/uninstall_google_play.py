import subprocess
import os

# First, check if Google Play Games is installed
print("=== Checking for Google Play Games installation ===\n")

# Check via winget
result = subprocess.run(
    ["winget", "list", "--name", "Google Play Games"],
    capture_output=True, text=True
)
print("winget list output:")
print(result.stdout)
if result.stderr:
    print("stderr:", result.stderr)

# Also check the AppData folder exists
gpg_path = r"C:\Users\lineb\AppData\Local\Google\Play Games"
print(f"\nFolder exists: {os.path.exists(gpg_path)}")

# Check if any Google Play Games processes are running
result2 = subprocess.run(
    ["tasklist", "/FI", "IMAGENAME eq GooglePlay*"],
    capture_output=True, text=True
)
print("\nRunning processes:")
print(result2.stdout)
