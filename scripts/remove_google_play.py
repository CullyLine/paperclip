import subprocess
import sys

print("Step 1: Killing Google Play Games processes...")
subprocess.run(["taskkill", "/F", "/IM", "GooglePlayGamesServices.exe"], capture_output=True)
subprocess.run(["taskkill", "/F", "/IM", "GooglePlayGames.exe"], capture_output=True)
subprocess.run(["taskkill", "/F", "/IM", "crosvm.exe"], capture_output=True)
print("  Done.\n")

print("Step 2: Uninstalling Google Play Games via winget...")
result = subprocess.run(
    ["winget", "uninstall", "--id", "Google.PlayGames", "--accept-source-agreements"],
    capture_output=False,
    text=True
)
print(f"\n  Uninstall exit code: {result.returncode}")

if result.returncode == 0:
    print("\nGoogle Play Games has been uninstalled!")
    print("The leftover data folder may still exist at:")
    print(r"  C:\Users\lineb\AppData\Local\Google\Play Games")
    print("\nCheck if it was cleaned up automatically, or we can delete it manually.")
else:
    print("\nUninstall may have failed or needs manual confirmation.")
    print("You may need to uninstall from Windows Settings > Apps > Google Play Games.")
