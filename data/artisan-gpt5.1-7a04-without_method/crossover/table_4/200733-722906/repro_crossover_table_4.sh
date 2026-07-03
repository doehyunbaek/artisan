#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Defect Detection Rates. For each fuzzer, we report the defect detection rate of each discovered defect across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest detection rate or rates (in the case of a tie) for each time and defect is highlighted in blue. Detection rates that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       | B0 [2] 5M | B0 [2] 3H | B1 [3] 5M | B1 [3] 3H | C0 [11] 5M | C0 [11] 3H | C1 [12] 5M | C1 [12] 3H | N0 [42] 5M | N0 [42] 3H | N1 [40] 5M | N1 [40] 3H | N2 [41] 5M | N2 [41] 3H | R0 [31] 5M | R0 [31] 3H | R1 [30] 5M | R1 [30] 3H | R2 [28] 5M | R2 [28] 3H | R3 [29] 5M | R3 [29] 3H | R4 [32] 5M | R4 [32] 3H |
| ------------ | --------: | --------: | --------: | --------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |
| BeDiv-Simple |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| BeDiv-Struct |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| RLCheck      |         - |         - |         - |         - |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zest         |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-X     |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-1PT   |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-2PT   |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-Link  |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Section 3: Reproduction commands (populate from reviewed steps)
# Compute defect detection rates from detections.csv and write Markdown table to /workspace/repro.txt
python - << 'PY'
import csv
from collections import defaultdict

def parse_time(s: str):
    """Parse 'D days HH:MM:SS[.fraction]' to total seconds (float)."""
    s = s.strip()
    if not s or s.upper() == "NAT":
        return None
    parts = s.split()
    # Expected like "0 days 01:00:34.474000"
    if len(parts) >= 3:
        days_str, _, time_part = parts[0], parts[1], parts[2]
    else:
        days_str = parts[0]
        time_part = parts[-1]
    days = int(days_str)
    h_str, m_str, sec_str = time_part.split(":")
    if "." in sec_str:
        sec_int_str, frac_str = sec_str.split(".", 1)
        sec = int(sec_int_str)
        try:
            frac = float("0." + frac_str)
        except ValueError:
            frac = 0.0
    else:
        sec = int(sec_str)
        frac = 0.0
    return days * 86400.0 + int(h_str) * 3600.0 + int(m_str) * 60.0 + sec + frac

# Load detection times grouped by (fuzzer, defect)
times_map = defaultdict(list)
with open("detections.csv", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        t_str = (row.get("time") or "").strip()
        t_val = parse_time(t_str) if t_str else None
        key = (row["fuzzer"], row["defect"])
        times_map[key].append(t_val)

# Fuzzer and defect orders, with citations, matching the target table
fuzzer_order = [
    "BeDiv-Simple",
    "BeDiv-Struct",
    "RLCheck",
    "Zest",
    "Zeugma-X",
    "Zeugma-1PT",
    "Zeugma-2PT",
    "Zeugma-Link",
]
defect_order = ["B0", "B1", "C0", "C1", "N0", "N1", "N2", "R0", "R1", "R2", "R3", "R4"]
defect_cites = {
    "B0": "[2]",
    "B1": "[3]",
    "C0": "[11]",
    "C1": "[12]",
    "N0": "[42]",
    "N1": "[40]",
    "N2": "[41]",
    "R0": "[31]",
    "R1": "[30]",
    "R2": "[28]",
    "R3": "[29]",
    "R4": "[32]",
}
# Thresholds: 5 minutes and 3 hours (seconds)
thresholds = [("5M", 5 * 60.0), ("3H", 3 * 3600.0)]

def detection_rate(key, thresh_seconds):
    vals = times_map.get(key, [])
    if not vals:
        # No campaigns for this (fuzzer, defect) combination
        return None
    total = len(vals)
    detected = sum(1 for v in vals if v is not None and v < thresh_seconds)
    return detected / float(total) if total > 0 else None

# Build Markdown table
header_cells = ["Fuzzer"]
for defect in defect_order:
    cite = defect_cites[defect]
    for label, _ in thresholds:
        header_cells.append(f"{defect} {cite} {label}")
align_cells = ["------------"] + ["--------:" for _ in range(len(header_cells) - 1)]

lines = []
lines.append("| " + " | ".join(header_cells) + " |")
lines.append("| " + " | ".join(align_cells) + " |")

for fuzzer in fuzzer_order:
    row_cells = [fuzzer]
    for defect in defect_order:
        key = (fuzzer, defect)
        for _, thresh in thresholds:
            rate = detection_rate(key, thresh)
            if rate is None:
                cell = "-"
            else:
                cell = f"{rate:.2f}"
            row_cells.append(cell)
    lines.append("| " + " | ".join(row_cells) + " |")

with open("/workspace/repro.txt", "w", encoding="utf-8") as out:
    out.write("**Table 4: Defect Detection Rates (reproduction).**\n\n")
    for line in lines:
        out.write(line + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
