#!/usr/bin/env python3
"""Audit Downhill Madness `done` issues: Luau paths in thread vs files on disk; CEO review signals."""

from __future__ import annotations

import json
import os
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

API = "http://localhost:3100"
COMPANY = "3dda8ba9-a1c2-466b-9809-1cc2a9d30b43"
DM = "c41aa681-284a-44f6-b0f6-ccf751d8cdb9"
CEO = "d380c57a-a52a-4bd0-b0a3-3eae9c349128"
ROOT = Path(__file__).resolve().parents[1] / "memories" / "DownhillMadness"

PAT_DM = re.compile(
    r"\b(DM(?:ServerScriptService|StarterPlayerScripts|ReplicatedStorage|StarterGui)/[\w./-]+\.luau)\b",
    re.I,
)
PAT_MEM = re.compile(
    r"\bmemories/DownhillMadness/((?:DM(?:ServerScriptService|StarterPlayerScripts|ReplicatedStorage|StarterGui)/)[\w./-]+\.luau)\b",
    re.I,
)
PAT_TICK = re.compile(r"`([^`]+\.luau)`", re.I)

NEG_APPROVAL = ("not approved", "don't approve", "do not approve", "without board approval")


def get(url: str) -> object:
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.loads(r.read().decode())


def normalize(rel: str) -> Path | None:
    rel = rel.replace("\\", "/").strip().strip("`")
    low = rel.lower()
    if low.startswith("memories/downhillmadness/"):
        rel = rel[len("memories/DownhillMadness/") :]
    if rel.startswith("DM"):
        return ROOT / rel.replace("/", os.sep)
    return None


def ceo_review_signal(comments: list) -> bool:
    """CEO comment that likely closes / accepts work (wording varies)."""
    needles = (
        "review approved",
        "ceo approved",
        "**review approved",
        "review (ceo): accepted",
        "(ceo): accepted",
        "marking done",
        "approved pol-",
        "approved [pol-",
        "meets bar",
        "meet bar",
    )
    for c in comments:
        if c.get("authorAgentId") != CEO:
            continue
        b = c.get("body") or ""
        bl = b.lower()
        if any(n in bl for n in NEG_APPROVAL):
            continue
        if any(n in bl for n in needles):
            return True
        if re.search(r"\baccepted\.\s", bl) and (
            "mp3" in bl or "implementation" in bl or "store" in bl or "patch notes" in bl
        ):
            return True
        if re.search(r"\bapproved\.\s", bl) and len(b) < 400:
            # Short "Approved. ..." closing notes
            return True
        if re.search(r"\bapproved\b", bl) and "reassigning to" not in bl and "please move" not in bl:
            if any(
                x in bl
                for x in (
                    "implementation",
                    "store page",
                    "copy in docs",
                    "lgtm",
                    "ready for",
                    "pol-",
                    "subtasks",
                    "epic",
                )
            ):
                return True
    return False


def extract_paths(text: str) -> set[str]:
    found: set[str] = set()
    for m in PAT_DM.finditer(text or ""):
        found.add(m.group(1))
    for m in PAT_MEM.finditer(text or ""):
        found.add(m.group(1))
    for m in PAT_TICK.finditer(text or ""):
        raw = m.group(1).replace("\\", "/")
        if "DM" in raw and raw.endswith(".luau"):
            if "memories/DownhillMadness/" in raw:
                raw = raw.split("memories/DownhillMadness/")[-1]
            if raw.startswith("DM"):
                found.add(raw)
    return found


def check_issue(iss: dict, comments: list) -> dict:
    ident = iss.get("identifier") or iss["id"][:8]
    title = (iss.get("title") or "")[:80]
    blob = (iss.get("description") or "") + "\n"
    blob += "\n".join(c.get("body", "") for c in comments)
    paths = extract_paths(blob)

    checked: list[tuple[str, bool]] = []
    for rel in sorted(paths):
        full = normalize(rel)
        if full is None:
            continue
        checked.append((rel, full.is_file()))

    bad = [r for r, ok in checked if not ok]
    good = [r for r, ok in checked if ok]
    return {
        "ident": ident,
        "title": title,
        "ceo_signal": ceo_review_signal(comments),
        "has_paths": bool(checked),
        "missing": bad,
        "ok_paths": good,
    }


def main() -> None:
    issues = get(f"{API}/api/companies/{COMPANY}/issues?projectId={DM}&status=done&limit=500")
    if not isinstance(issues, list):
        print("Unexpected response:", type(issues))
        return

    issues = sorted(issues, key=lambda x: x.get("issueNumber") or 0)
    id_to_comments: dict[str, list] = {}
    with ThreadPoolExecutor(max_workers=12) as ex:
        futs = {
            ex.submit(get, f"{API}/api/issues/{iss['id']}/comments"): iss["id"] for iss in issues
        }
        for fut in as_completed(futs):
            iid = futs[fut]
            id_to_comments[iid] = fut.result()

    rows: list[dict] = []
    for iss in issues:
        rows.append(check_issue(iss, id_to_comments.get(iss["id"], [])))

    all_missing = [r for r in rows if r["has_paths"] and r["missing"]]
    no_paths = [r for r in rows if not r["has_paths"]]
    all_ok = [r for r in rows if r["has_paths"] and not r["missing"]]

    ceo_subset = [r for r in rows if r["ceo_signal"]]
    ceo_missing = [r for r in ceo_subset if r["has_paths"] and r["missing"]]
    ceo_no_paths = [r for r in ceo_subset if not r["has_paths"]]

    print("=== Downhill Madness audit: `done` issues vs repo Luau paths ===\n")
    print(f"Repo: {ROOT}")
    print(f"Total `done` DM issues: {len(issues)}\n")

    print("--- A) ANY done issue: referenced DM*.luau missing on disk ---")
    for r in all_missing:
        print(f"  - {r['ident']}: {r['title']}")
        print(f"      MISSING: {r['missing']}")
        if r["ok_paths"]:
            print(f"      OK: {r['ok_paths']}")
    print(f"  Count: {len(all_missing)}\n")

    print("--- B) ANY done issue: no DM*.luau path found in description+comments ---")
    print("     (Cannot auto-verify from thread; often docs-only or prose summaries.)")
    for r in no_paths:
        flag = " [CEO review signal]" if r["ceo_signal"] else ""
        print(f"  - {r['ident']}: {r['title']}{flag}")
    print(f"  Count: {len(no_paths)}\n")

    print("--- C) Done issues WITH CEO review/approval signal (subset) ---")
    print(f"  Matched {len(ceo_subset)} issues.\n")
    print("  CEO signal + missing Luau on disk:")
    for r in ceo_missing:
        print(f"    - {r['ident']}: MISSING {r['missing']}")
    if not ceo_missing:
        print("    (none)")
    print("\n  CEO signal + no DM*.luau path in thread (cannot verify from paths):")
    for r in ceo_no_paths:
        print(f"    - {r['ident']}: {r['title']}")
    print(f"    Count: {len(ceo_no_paths)}\n")

    print("--- Summary ---")
    print(
        f"  Referenced Luau missing: {len(all_missing)} | "
        f"No path in thread: {len(no_paths)} | "
        f"Referenced Luau all OK: {len(all_ok)}"
    )
    print(
        f"  CEO signal: {len(ceo_subset)} | "
        f"of those, missing files: {len(ceo_missing)} | "
        f"no path in thread: {len(ceo_no_paths)}"
    )
    print("\nRe-run: python scripts/audit-dm-ceo-approved.py")


if __name__ == "__main__":
    main()
