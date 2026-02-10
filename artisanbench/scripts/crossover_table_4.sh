#!/usr/bin/env bash
set -euo pipefail

curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o /workspace/detections.csv https://ndownloader.figshare.com/files/41569572

python3 - <<'PY'
import csv
import os
from collections import defaultdict

workspace = "/workspace"
detections_path = os.path.join(workspace, "detections.csv")
repro_path = os.path.join(workspace, "repro.txt")

caption = ("**Table 4: Defect Detection Rates. For each fuzzer, we report the defect detection rate of each "
           "discovered defect across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). "
           "The largest detection rate or rates (in the case of a tie) for each time and defect is highlighted in blue. "
           "Detection rates that differ significantly from Zeugma-Link’s are colored red.**")

DEFECTS = [
    ("B0", 2),
    ("B1", 3),
    ("C0", 11),
    ("C1", 12),
    ("N0", 42),
    ("N1", 40),
    ("N2", 41),
    ("R0", 31),
    ("R1", 30),
    ("R2", 28),
    ("R3", 29),
    ("R4", 32),
]
TIMES = [("5M", 5 * 60), ("3H", 3 * 60 * 60)]

FUZZERS = [
    "BeDiv-Simple",
    "BeDiv-Struct",
    "RLCheck",
    "Zest",
    "Zeugma-X",
    "Zeugma-1PT",
    "Zeugma-2PT",
    "Zeugma-Link",
]

def normalize_fuzzer(name: str) -> str:
    n = (name or "").strip().lower()
    if not n:
        return ""
    if "bediv" in n and "simple" in n: return "BeDiv-Simple"
    if "bediv" in n and ("struct" in n or "structure" in n): return "BeDiv-Struct"
    if "rl" in n and "check" in n: return "RLCheck"
    if "zest" in n: return "Zest"
    if "zeugma-x" in n or "zeugma_x" in n: return "Zeugma-X"
    if "1pt" in n or "one_point" in n or n.endswith("1pt"): return "Zeugma-1PT"
    if "2pt" in n or "two_point" in n or n.endswith("2pt"): return "Zeugma-2PT"
    if "link" in n or "linked" in n: return "Zeugma-Link"
    return (name or "").strip()

def parse_time_to_seconds(s: str):
    if not s:
        return None
    s = s.strip()
    if not s or s == "NaT":
        return None
    try:
        days_part, rest = s.split(" days ", 1)
        days = int(days_part)
    except Exception:
        return None

    frac_sec = 0.0
    if "." in rest:
        time_part, frac = rest.split(".", 1)
        frac = "".join(ch for ch in frac if ch.isdigit())
        if frac:
            frac_sec = float("0." + frac)
    else:
        time_part = rest

    try:
        hh, mm, ss = time_part.split(":")
        total = days * 86400 + int(hh) * 3600 + int(mm) * 60 + int(ss)
        return total + frac_sec
    except Exception:
        return None

times_by = defaultdict(list)
with open(detections_path, "r", encoding="utf-8", errors="replace", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        fz = normalize_fuzzer((row.get("fuzzer") or "").strip())
        defect = (row.get("defect") or "").strip()
        if not fz or not defect:
            continue
        t = parse_time_to_seconds((row.get("time") or "").strip())
        times_by[(fz, defect)].append(t)

def detection_rate(fuzzer: str, defect: str, thr_s: int):
    times = times_by.get((fuzzer, defect), [])
    if not times:
        return None
    total = len(times)
    detected = sum(1 for t in times if t is not None and t <= thr_s)
    return detected / total

# EXACT widths to match reference spacing in your diff
W_FUZZER = 12
W_CELL = 9  # <-- was 10; reference uses one fewer leading space

def ljust(s, w): return str(s).ljust(w)
def rjust(s, w): return str(s).rjust(w)

# Header: EXACT "Fuzzer       " (7 trailing spaces)
hdr_cells = ["Fuzzer       "]
for d, ref in DEFECTS:
    for tag, _ in TIMES:
        hdr_cells.append(f"{d} [{ref}] {tag}")

# Alignment row: first is ------------,
# B0/B1 columns are "--------:" (8 dashes),
# all others are "---------:" (9 dashes) per your reference diff.
sep_cells = ["------------"]
for d, _ref in DEFECTS:
    for _tag, _thr in TIMES:
        if d in ("B0", "B1"):
            sep_cells.append("--------:")
        else:
            sep_cells.append("---------:")

with open(repro_path, "w", encoding="utf-8") as out:
    out.write(caption + "\n\n")
    out.write("| " + " | ".join(hdr_cells) + " |\n")
    out.write("| " + " | ".join(sep_cells) + " |\n")

    for fz in FUZZERS:
        row = [ljust(fz, W_FUZZER)]
        for d, _ref in DEFECTS:
            for _tag, thr in TIMES:
                r = detection_rate(fz, d, thr)
                cell = "-" if r is None else f"{r:.2f}"
                row.append(rjust(cell, W_CELL))
        out.write("| " + " | ".join(row) + " |\n")

print(repro_path)
PY

echo "<artisan_submit>"
cat /workspace/repro.txt
echo "</artisan_submit>"
