#!/usr/bin/bash
set -euo pipefail
cd /workspace
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| BeDiv-Struct |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| RLCheck      |     ???.? |  ???.? |          — |          — |      ????.? |      ????.? |    ???.? |      ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zest         |     ???.? |  ???.? |     ????.? |     ????.? |      ????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-X     |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-?PT   |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-?PT   |     ???.? |  ???.? |     ????.? |     ????.? |     ?????.? |     ?????.? |    ???.? |     ????.? |     ????.? |     ????.? |     ????.? |     ????.? |     ???.? |     ???.? |
| Zeugma-Link  | **???.?** |  ???.? | **????.?** | **????.?** | **?????.?** | **?????.?** |    ???.? | **????.?** | **????.?** | **????.?** | **????.?** | **????.?** | **???.?** | **???.?** |

EOTABLE
# Section 2: Artifact download
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879
# Section 3: Reproduction commands (populate from reviewed steps)
python3 - <<'PY' > /workspace/repro.txt
import csv
import statistics
from collections import defaultdict

FUZZERS = [
    'BeDiv-Simple',
    'BeDiv-Struct',
    'RLCheck',
    'Zest',
    'Zeugma-X',
    'Zeugma-1PT',
    'Zeugma-2PT',
    'Zeugma-Link',
]
SUBJECTS = ['Ant', 'Bcel', 'Closure', 'Maven', 'Nashorn', 'Rhino', 'Tomcat']
TIME_POINTS = [
    ('0 days 00:05:00', '5M'),
    ('0 days 03:00:00', '3H'),
]
TIME_VALUES = {tp[0] for tp in TIME_POINTS}

# Aggregate covered_branches by (fuzzer, subject, time)
data = defaultdict(list)
with open('coverage.csv', newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        time = row['time'].strip()
        if time not in TIME_VALUES:
            continue
        fuzzer = row['fuzzer'].strip()
        subject = row['subject'].strip()
        if fuzzer not in FUZZERS or subject not in SUBJECTS:
            continue
        try:
            covered = float(row['covered_branches'])
        except ValueError:
            continue
        data[(fuzzer, subject, time)].append(covered)

# Compute medians (or None where no data, e.g., RLCheck+BCEL)
medians = {}
for f in FUZZERS:
    for s in SUBJECTS:
        for time_value, _ in TIME_POINTS:
            key = (f, s, time_value)
            values = data.get(key, [])
            medians[key] = float(statistics.median(values)) if values else None

# Determine per-column maxima for bolding
max_by_col = {}
for s in SUBJECTS:
    for time_value, _ in TIME_POINTS:
        vals = [
            v
            for (ff, ss, tt), v in medians.items()
            if ss == s and tt == time_value and v is not None
        ]
        max_by_col[(s, time_value)] = max(vals) if vals else None

def format_cell(f, s, time_value):
    val = medians[(f, s, time_value)]
    if val is None:
        return '—'
    text = f"{val:.1f}"
    max_val = max_by_col[(s, time_value)]
    if max_val is not None and abs(val - max_val) < 1e-9:
        text = f"**{text}**"
    return text

print("**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**")
print()
print("| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |")
print("| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |")

for f in FUZZERS:
    cells = []
    for s in SUBJECTS:
        for time_value, _ in TIME_POINTS:
            cells.append(format_cell(f, s, time_value))
    row = f"| {f:<12} | " + " | ".join(cells) + " |"
    print(row)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
