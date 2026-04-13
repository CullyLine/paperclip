"""
Find Windows uninstall entries by substring match and run their uninstall command.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import winreg

# Substrings to match DisplayName (norm substring in display norm)
TARGETS = [
    "koikatsu",
    "my time at sandrock",
    "pokemon bd+sp",
    "adobe premiere pro 2022",
    "pokemon legends: z-a",
    "voicemod",
    "bluestacks",
]

UNINSTALL_KEYS = [
    (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
    (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
    (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
]


def norm(s: str) -> str:
    return s.lower().strip()


def find_matches() -> dict[str, dict]:
    found: dict[str, dict] = {}

    for hive, path in UNINSTALL_KEYS:
        try:
            with winreg.OpenKey(hive, path) as root:
                i = 0
                while True:
                    try:
                        sub = winreg.EnumKey(root, i)
                    except OSError:
                        break
                    i += 1
                    try:
                        with winreg.OpenKey(root, sub) as key:
                            def get_str(name: str) -> str:
                                try:
                                    v, _ = winreg.QueryValueEx(key, name)
                                    return str(v).strip() if v is not None else ""
                                except OSError:
                                    return ""

                            display = get_str("DisplayName")
                            if not display:
                                continue
                            dnorm = norm(display)
                            for target in TARGETS:
                                tnorm = norm(target)
                                if tnorm not in dnorm:
                                    continue
                                prev = found.get(target)
                                if prev is None or len(display) > len(prev["display"]):
                                    found[target] = {
                                        "display": display,
                                        "quiet": get_str("QuietUninstallString"),
                                        "uninstall": get_str("UninstallString"),
                                        "key": f"{hive}\\{path}\\{sub}",
                                    }
                    except OSError:
                        continue
        except OSError:
            continue

    return found


def run_uninstall(entry: dict) -> int:
    cmd = (entry.get("quiet") or entry.get("uninstall") or "").strip()
    if not cmd:
        print("  No UninstallString.", file=sys.stderr)
        return 1

    if cmd.lower().startswith("msiexec"):
        cmd = re.sub(r"/I(\{[^}]+\})", r"/X\1", cmd, flags=re.I)
        if "/quiet" not in cmd.lower() and "/qn" not in cmd.lower():
            cmd += " /quiet /norestart"

    print(f"  {cmd[:200]}{'...' if len(cmd) > 200 else ''}")
    return subprocess.call(cmd, shell=True)


def main() -> int:
    matches = find_matches()
    print("Resolved:")
    for t in TARGETS:
        m = matches.get(t)
        print(f"  {'OK ' if m else 'MISS'} {t!r} -> {m['display'] if m else '?'}")

    code = 0
    for t in TARGETS:
        m = matches.get(t)
        if not m:
            continue
        print(f"\n--- {m['display']} ---")
        c = run_uninstall(m)
        if c != 0:
            code = c
            print(f"  exit {c}")

    return code


if __name__ == "__main__":
    if os.name != "nt":
        print("Windows only.")
        sys.exit(1)
    sys.exit(main())
