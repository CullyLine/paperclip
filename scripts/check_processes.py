import subprocess
import json

result = subprocess.run(
    ["tasklist", "/FO", "CSV", "/V"],
    capture_output=True, text=True
)

lines = result.stdout.strip().split("\n")
header = lines[0]

import csv
import io

reader = csv.reader(io.StringIO(result.stdout))
headers = next(reader)

processes = []
for row in reader:
    try:
        name = row[0]
        pid = row[1]
        mem_str = row[4].replace(",", "").replace(" K", "").replace("\"", "")
        try:
            mem_kb = int(mem_str)
        except ValueError:
            mem_kb = 0
        status = row[5] if len(row) > 5 else ""
        title = row[-1] if len(row) > 6 else ""
        processes.append({
            "name": name,
            "pid": pid,
            "mem_mb": mem_kb / 1024,
            "status": status,
            "title": title
        })
    except (IndexError, ValueError):
        pass

# Group by process name and sum memory
from collections import defaultdict
grouped = defaultdict(lambda: {"count": 0, "mem_mb": 0, "pids": []})
for p in processes:
    key = p["name"]
    grouped[key]["count"] += 1
    grouped[key]["mem_mb"] += p["mem_mb"]
    grouped[key]["pids"].append(p["pid"])

# Sort by total memory usage
sorted_procs = sorted(grouped.items(), key=lambda x: x[1]["mem_mb"], reverse=True)

print(f"{'PROCESS':<45} {'COUNT':>5} {'MEMORY':>10}")
print("=" * 65)
for name, info in sorted_procs:
    if info["mem_mb"] > 5:
        print(f"{name:<45} {info['count']:>5} {info['mem_mb']:>8.0f} MB")

print(f"\n{'='*65}")
print(f"Total processes: {len(processes)}")
total_mem = sum(p["mem_mb"] for p in processes)
print(f"Total memory usage: {total_mem/1024:.1f} GB")
