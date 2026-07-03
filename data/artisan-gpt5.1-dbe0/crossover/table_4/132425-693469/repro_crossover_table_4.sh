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
python - << 'PY'
import csv
import re

detections_path = "/workspace/detections.csv"
output_path = "/workspace/repro.txt"

fuzzers = [
    "BeDiv-Simple",
    "BeDiv-Struct",
    "RLCheck",
    "Zest",
    "Zeugma-X",
    "Zeugma-1PT",
    "Zeugma-2PT",
    "Zeugma-Link",
]

defects = [
    "B0", "B1",
    "C0", "C1",
    "N0", "N1", "N2",
    "R0", "R1", "R2", "R3", "R4",
]

# Stats: (fuzzer, defect) -> dict(total, det_5m, det_3h)
stats = {}

time_re = re.compile(r"(\d+)\s+days\s+(\d+):(\d+):(\d+)(?:\.(\d+))?")

def parse_seconds(t: str) -> float:
    m = time_re.fullmatch(t)
    if not m:
        raise ValueError(f"Unexpected time format: {t!r}")
    days, hh, mm, ss, frac = m.groups()
    days = int(days); hh = int(hh); mm = int(mm); ss = int(ss)
    total = days * 86400 + hh * 3600 + mm * 60 + ss
    if frac:
        total += int(frac) / (10 ** len(frac))
    return total

THREE_HOURS = 3 * 60 * 60          # 10800 seconds
FIVE_MINUTES = 5 * 60              # 300 seconds

with open(detections_path, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        fuzzer = row["fuzzer"]
        defect = row["defect"]
        time_str = (row.get("time") or "").strip()

        if fuzzer not in fuzzers or defect not in defects:
            continue

        key = (fuzzer, defect)
        s = stats.setdefault(key, {"total": 0, "det_5m": 0, "det_3h": 0})
        s["total"] += 1

        if time_str:
            secs = parse_seconds(time_str)
            # Any listed time corresponds to detection within the 3-hour campaign
            if secs <= THREE_HOURS:
                s["det_3h"] += 1
            # 5M detection if within first five minutes
            if secs <= FIVE_MINUTES:
                s["det_5m"] += 1

def rate_strings(fuzzer, defect):
    key = (fuzzer, defect)
    s = stats.get(key)
    if s is None or s["total"] == 0:
        return "-", "-"
    total = s["total"]
    # Detection rate as proportion of campaigns, not percentage
    r5 = s["det_5m"] / total
    r3 = s["det_3h"] / total
    return f"{r5:.2f}", f"{r3:.2f}"

header = "**Table 4: Defect Detection Rates. For each fuzzer, we report the defect detection rate of each discovered defect across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest detection rate or rates (in the case of a tie) for each time and defect is highlighted in blue. Detection rates that differ significantly from Zeugma-Link’s are colored red.**"

columns = [
    ("B0 [2] 5M", "B0", "5M"),
    ("B0 [2] 3H", "B0", "3H"),
    ("B1 [3] 5M", "B1", "5M"),
    ("B1 [3] 3H", "B1", "3H"),
    ("C0 [11] 5M", "C0", "5M"),
    ("C0 [11] 3H", "C0", "3H"),
    ("C1 [12] 5M", "C1", "5M"),
    ("C1 [12] 3H", "C1", "3H"),
    ("N0 [42] 5M", "N0", "5M"),
    ("N0 [42] 3H", "N0", "3H"),
    ("N1 [40] 5M", "N1", "5M"),
    ("N1 [40] 3H", "N1", "3H"),
    ("N2 [41] 5M", "N2", "5M"),
    ("N2 [41] 3H", "N2", "3H"),
    ("R0 [31] 5M", "R0", "5M"),
    ("R0 [31] 3H", "R0", "3H"),
    ("R1 [30] 5M", "R1", "5M"),
    ("R1 [30] 3H", "R1", "3H"),
    ("R2 [28] 5M", "R2", "5M"),
    ("R2 [28] 3H", "R2", "3H"),
    ("R3 [29] 5M", "R3", "5M"),
    ("R3 [29] 3H", "R3", "3H"),
    ("R4 [32] 5M", "R4", "5M"),
    ("R4 [32] 3H", "R4", "3H"),
]

align = "| ------------ | " + " | ".join(["--------:" for _ in columns]) + " |"

with open(output_path, "w") as out:
    out.write(header + "\n\n")
    # Header row
    header_cells = ["Fuzzer"] + [c[0] for c in columns]
    out.write("| " + " | ".join(header_cells) + " |\n")
    out.write(align + "\n")

    for fuzzer in fuzzers:
        row_cells = [fuzzer]
        for _, defect, which in columns:
            r5, r3 = rate_strings(fuzzer, defect)
            val = r5 if which == "5M" else r3
            row_cells.append(val.rjust(6))
        out.write("| " + " | ".join(row_cells) + " |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
