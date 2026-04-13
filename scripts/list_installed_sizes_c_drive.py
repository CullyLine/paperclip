"""
Read-only: installed programs with EstimatedSize, filtered to C: drive only.
Uses InstallLocation when set; else first absolute path from UninstallString/QuietUninstallString.
"""
from __future__ import annotations

import os
import re
import shutil
import sys
import winreg

UNINSTALL_KEYS = [
    (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
    (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
    (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
]

PATH_RE = re.compile(r'[A-Za-z]:\\[^"\s]+|"([A-Za-z]:[^"]+)"')


def first_path_on_drive(s: str) -> str | None:
    if not s:
        return None
    # Quoted paths first
    for m in re.finditer(r'"([A-Za-z]:[^"]+)"', s):
        return m.group(1)
    m = re.match(r"([A-Za-z]:\\[^\s]+)", s.strip())
    if m:
        return m.group(1).rstrip("\\")
    return None


def is_c_drive_path(p: str | None) -> bool:
    if not p:
        return False
    p = p.strip().strip('"')
    if len(p) < 2:
        return False
    return p[0].upper() == "C" and p[1] == ":"


def iter_entries():
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

                            def get_int(name: str) -> int | None:
                                try:
                                    v, typ = winreg.QueryValueEx(key, name)
                                    if typ == winreg.REG_DWORD:
                                        return int(v)
                                    if typ == winreg.REG_SZ and str(v).isdigit():
                                        return int(str(v))
                                    return None
                                except OSError:
                                    return None

                            name = get_str("DisplayName")
                            if not name or name.startswith("KB"):
                                continue
                            loc = get_str("InstallLocation")
                            quiet = get_str("QuietUninstallString")
                            uninstall = get_str("UninstallString")
                            path_guess = loc or first_path_on_drive(quiet) or first_path_on_drive(uninstall)
                            if not is_c_drive_path(path_guess or ""):
                                continue
                            size_kb = get_int("EstimatedSize")
                            yield {
                                "name": name,
                                "publisher": get_str("Publisher")[:50],
                                "size_kb": size_kb,
                                "path": path_guess or "(C:)",
                            }
                    except OSError:
                        continue
        except OSError:
            continue


def main() -> None:
    du = shutil.disk_usage("C:\\")
    free_gb = du.free / (1024**3)
    total_gb = du.total / (1024**3)
    used_gb = (du.total - du.free) / (1024**3)
    print(f"C: {free_gb:.1f} GB free  |  {used_gb:.1f} GB used  |  {total_gb:.1f} GB total\n")

    entries = list(iter_entries())
    # Dedupe by name+path, keep max size
    best: dict[tuple[str, str], dict] = {}
    for e in entries:
        k = (e["name"], e["path"])
        prev = best.get(k)
        if prev is None or (e.get("size_kb") or 0) > (prev.get("size_kb") or 0):
            best[k] = e

    with_size = [e for e in best.values() if e.get("size_kb")]
    without = [e for e in best.values() if not e.get("size_kb")]
    with_size.sort(key=lambda x: x["size_kb"] or 0, reverse=True)

    print("=== C: installs with reported size (top 35) ===\n")
    for e in with_size[:35]:
        mb = (e["size_kb"] or 0) / 1024
        print(f"{mb:8.1f} MB  {e['name'][:65]}")
        print(f"          {e['path'][:95]}")

    print(f"\n(C: only) {len(with_size)} with size, {len(without)} without size in registry.")
    print("Entries without InstallLocation may be misclassified; verify in Settings > Apps.")


if __name__ == "__main__":
    if os.name != "nt":
        print("Windows only.")
        sys.exit(1)
    main()
