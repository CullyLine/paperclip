"""
Summarize disk usage: C:\\ top-level folders + notable root files.
Uses parallel walks; skips System Volume Information inside walks.
Read-only.
"""
from __future__ import annotations

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

SKIP_DIR_NAMES = frozenset({"System Volume Information"})


def dir_size_bytes(root: str) -> tuple[str, int]:
    total = 0
    root = os.path.normpath(root)
    try:
        for walk_root, dirs, files in os.walk(root, topdown=True):
            dirs[:] = [d for d in dirs if d not in SKIP_DIR_NAMES]
            for name in files:
                fp = os.path.join(walk_root, name)
                try:
                    total += os.path.getsize(fp)
                except OSError:
                    pass
    except OSError:
        pass
    return root, total


def root_file_size(path: str) -> tuple[str, int]:
    try:
        return path, os.path.getsize(path)
    except OSError:
        return path, 0


def main() -> None:
    c = "C:\\"
    children: list[str] = []
    try:
        for name in os.listdir(c):
            p = os.path.join(c, name)
            if os.path.isdir(p):
                children.append(p)
            elif os.path.isfile(p):
                children.append(p)
    except OSError as e:
        print("Cannot list C:\\:", e)
        sys.exit(1)

    # Parallel per top-level item (folders are heavy)
    results: list[tuple[str, int]] = []
    workers = min(6, max(2, len(children)))
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = []
        for p in children:
            if os.path.isdir(p):
                futures.append(ex.submit(dir_size_bytes, p))
            else:
                futures.append(ex.submit(root_file_size, p))
        for fut in as_completed(futures):
            results.append(fut.result())

    results.sort(key=lambda x: x[1], reverse=True)

    def gb(n: int) -> float:
        return n / (1024**3)

    total = sum(x[1] for x in results)
    print(f"C:\\ top-level scan (approximate; some system paths may under-report)\n")
    print(f"{'Size (GB)':>12}  {'Path'}")
    print("-" * 72)
    for path, nbytes in results:
        label = path
        if len(label) > 58:
            label = label[:55] + "..."
        print(f"{gb(nbytes):12.2f}  {label}")
    print("-" * 72)
    print(f"{gb(total):12.2f}  TOTAL (sum of items above)")

    # Second-level breakdown for largest folders (top 4)
    print("\n--- Largest subfolders inside top 4 dirs ---\n")
    big_dirs = [p for p, _ in results if os.path.isdir(p)][:4]
    for parent in big_dirs:
        subs: list[tuple[str, int]] = []
        try:
            for name in os.listdir(parent):
                p = os.path.join(parent, name)
                if os.path.isdir(p):
                    subs.append(p)
        except OSError as e:
            print(f"{parent}: cannot list ({e})\n")
            continue
        if not subs:
            continue
        with ThreadPoolExecutor(max_workers=min(6, len(subs))) as ex:
            futs = [ex.submit(dir_size_bytes, s) for s in subs]
            sub_results = [f.result() for f in futs]
        sub_results.sort(key=lambda x: x[1], reverse=True)
        print(f"[{parent}]")
        for path, nbytes in sub_results[:12]:
            short = path if len(path) < 62 else path[:59] + "..."
            print(f"  {gb(nbytes):8.2f} GB  {short}")
        print()


if __name__ == "__main__":
    if os.name != "nt":
        print("Windows only.")
        sys.exit(1)
    main()
