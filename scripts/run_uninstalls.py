"""Run approved uninstallers; invoked as: python run_uninstalls.py"""
import subprocess
import sys

# (label, full command string for cmd)
STEPS = [
    ("Koikatsu", r'"F:\Games\Koikatsu\unins000.exe" /SILENT'),
    ("My Time at Sandrock", r'"G:\Games\My Time at Sandrock\unins000.exe" /SILENT'),
    (
        "Pokemon BD+SP",
        r'"G:\SwitchHacking\Pokemon Brilliant Diamond and Shining Pearl\unins000.exe" /SILENT',
    ),
    (
        "Adobe Premiere Pro 2022",
        r'"C:\Program Files (x86)\Common Files\Adobe\Adobe Desktop Common\HDBox\Uninstaller.exe" '
        r'--uninstall=1 --sapCode=PPRO --productVersion=22.3.1 --productPlatform=win64 '
        r'--productAdobeCode={PPRO-22.3.1-64-ADBEADBEADBEADBEADBEA} '
        r'--productName="Premiere Pro" --mode=2',
    ),
    ("Pokemon Legends Z-A", r'"G:\DD\PokemonLegendsZ-AInstalled\unins000.exe" /SILENT'),
    ("Voicemod", r'"C:\Program Files\Voicemod Desktop\unins000.exe" /SILENT'),
    # BlueStacks: registry had -tmp; try uninstaller without (common pattern)
    ("BlueStacks 5", r'"C:\Program Files\BlueStacks_nxt\BlueStacksUninstaller.exe"'),
]


def main() -> int:
    last = 0
    for name, cmd in STEPS:
        print(f"\n=== {name} ===")
        print(cmd[:160] + ("..." if len(cmd) > 160 else ""))
        last = subprocess.call(cmd, shell=True)
        print(f"exit code: {last}")
    return last


if __name__ == "__main__":
    sys.exit(main())
