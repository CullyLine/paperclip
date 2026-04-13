"""
Read-only: list Windows uninstall entries with EstimatedSize from registry.
Does not uninstall or modify anything.
"""
from __future__ import annotations

import os
import shutil
import winreg

UNINSTALL_KEYS = [
    (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
    (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
    (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
]


def iter_uninstall_entries():
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
                            # Skip system components with no size often
                            size_kb = get_int("EstimatedSize")
                            yield {
                                "name": name,
                                "publisher": get_str("Publisher"),
                                "version": get_str("DisplayVersion"),
                                "size_kb": size_kb,
                                "location": f"{hive}\\{path}\\{sub}",
                            }
                    except OSError:
                        continue
        except OSError:
            continue


def main() -> None:
    du = shutil.disk_usage("C:\\")
    free_gb = du.free / (1024**3)
    total_gb = du.total / (1024**3)
    print(f"C: {free_gb:.1f} GB free of {total_gb:.1f} GB total\n")

    entries = list(iter_uninstall_entries())
    # Dedupe by name+version, keep largest size_kb if duplicate
    seen: dict[tuple[str, str], dict] = {}
    for e in entries:
        k = (e["name"], e["version"])
        prev = seen.get(k)
        if prev is None:
            seen[k] = e
        else:
            a, b = prev.get("size_kb"), e.get("size_kb")
            if (b or 0) > (a or 0):
                seen[k] = e

    with_size = [e for e in seen.values() if e.get("size_kb")]
    without = [e for e in seen.values() if not e.get("size_kb")]

    with_size.sort(key=lambda x: x["size_kb"] or 0, reverse=True)

    print("=== Installed programs with reported size (top 40) ===\n")
    for e in with_size[:40]:
        mb = e["size_kb"] / 1024
        pub = (e["publisher"] or "")[:40]
        print(f"{mb:8.1f} MB  {e['name'][:70]}")
        if pub:
            print(f"          ({pub})")

    print(f"\n... {len(with_size)} total with size; {len(without)} without size in registry")
    print("\nNote: Many apps do not report EstimatedSize — check Settings > Apps > Sort by size.")
    print("This script does not uninstall anything.")


if __name__ == "__main__":
    if os.name != "nt":
        print("This script is for Windows only.")
    else:
        main()
