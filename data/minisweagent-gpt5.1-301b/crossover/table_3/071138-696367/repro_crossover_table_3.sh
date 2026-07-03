#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       |    Ant 5M | Ant 3H |    BCEL 5M |    BCEL 3H |  Closure 5M |  Closure 3H | Maven 5M |   Maven 3H | Nashorn 5M | Nashorn 3H |   Rhino 5M |   Rhino 3H | Tomcat 5M | Tomcat 3H |
| ------------ | --------: | -----: | ---------: | ---------: | ----------: | ----------: | -------: | ---------: | ---------: | ---------: | ---------: | ---------: | --------: | --------: |
| BeDiv-Simple |     755.0 |  899.0 |     1435.5 |     1846.5 |      9328.0 |     11863.5 |    590.5 |      738.0 |     3008.5 |     3319.5 |     2952.0 |     3235.5 |     274.5 |     341.0 |
| BeDiv-Struct |     786.5 |  896.5 |     1412.5 |     1876.5 |      9336.5 |     11904.5 |    578.5 |      641.5 |     2993.5 |     3092.0 |     2915.5 |     3237.0 |     161.0 |     242.5 |
| RLCheck      |     769.0 |  889.0 |          — |          — |      8262.5 |      9480.5 |    579.0 |      663.0 |     1298.0 |     1298.0 |     2627.0 |     2730.0 |     299.0 |     338.0 |
| Zest         |     820.0 |  927.0 |     1516.5 |     1909.5 |      9782.5 |     12352.0 |    778.5 |     1098.5 |     2654.5 |     2717.0 |     3108.5 |     3408.0 |     295.0 |     340.0 |
| Zeugma-X     |     835.5 |  911.0 |     1480.5 |     1927.0 |     10274.5 |     12251.0 |    873.0 |     1138.0 |     4259.0 |     7411.0 |     3169.0 |     3551.5 |     297.5 |     345.0 |
| Zeugma-1PT   |     828.0 |  909.5 |     1489.0 |     1917.0 |     10237.5 |     12153.5 |    855.5 |     1138.0 |     4166.0 |     7369.5 |     3169.0 |     3572.5 |     294.0 |     344.0 |
| Zeugma-2PT   |     819.5 |  910.0 |     1472.0 |     1915.0 |     10284.0 |     12038.0 |    797.0 |     1134.0 |     3962.5 |     7310.0 |     3143.0 |     3549.0 |     291.0 |     341.5 |
| Zeugma-Link  | **845.5** |  911.5 | **1541.5** | **1959.0** | **10395.5** | **12709.0** |    906.0 | **1138.0** | **5568.5** | **7654.0** | **3233.5** | **3703.0** | **295.5** | **345.0** |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace
cd /workspace
# Download artifact README and coverage dataset (used for Table 3)
curl -L "https://ndownloader.figshare.com/files/43895979" -o README.md
curl -L "https://ndownloader.figshare.com/files/41569581" -o coverage.csv

# Section 3: Reproduction commands (populate from reviewed steps)
# Compute per-(fuzzer, subject) median branch coverage at 5 minutes and 3 hours
python - << 'PY' > /workspace/repro.txt
import csv
from collections import defaultdict
from statistics import median

path = "/workspace/coverage.csv"
t5 = "0 days 00:05:00"
t3 = "0 days 03:00:00"

# Collect coverage values per (fuzzer, subject, time-label)
data = defaultdict(list)
with open(path, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        t = row["time"]
        if t not in (t5, t3):
            continue
        cov = float(row["covered_branches"])
        fz = row["fuzzer"]
        subj = row["subject"]
        label = "5M" if t == t5 else "3H"
        data[(fz, subj, label)].append(cov)

# Compute medians
medians = {k: median(v) for k, v in data.items() if v}

# Order and labels as in the paper
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
subjects = ["Ant", "Bcel", "Closure", "Maven", "Nashorn", "Rhino", "Tomcat"]
header_subject_labels = {
    "Ant": "Ant",
    "Bcel": "BCEL",
    "Closure": "Closure",
    "Maven": "Maven",
    "Nashorn": "Nashorn",
    "Rhino": "Rhino",
    "Tomcat": "Tomcat",
}

# Determine per-(subject,time) maxima for boldfacing
max_by_subject_time = {}
for subj in subjects:
    for label in ("5M", "3H"):
        vals = []
        for fz in fuzzers:
            key = (fz, subj, label)
            if key in medians:
                vals.append(medians[key])
        max_by_subject_time[(subj, label)] = max(vals) if vals else None

# Build header
cols = []
for subj in subjects:
    cols.append(f"{header_subject_labels[subj]} 5M")
    cols.append(f"{header_subject_labels[subj]} 3H")

header = "| Fuzzer       | " + " | ".join(cols) + " |"
align = "| ------------ | " + " | ".join(["--------:"] * len(cols)) + " |"

print("**Table 3: Branch Coverage. For each fuzzer, we report the median branch coverage in application classes for each subject across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest median or medians (in the case of a tie) for each time and subject is highlighted in blue. Branch coverage values that differ significantly from Zeugma-Link’s are colored red.**")
print()
print(header)
print(align)

def fmt_cell(fz, subj, label):
    key = (fz, subj, label)
    val = medians.get(key)
    if val is None:
        # RLCheck on Bcel: no campaigns, render as em dash
        return "         —"
    s = f"{val:.1f}"
    m = max_by_subject_time.get((subj, label))
    if m is not None and abs(val - m) < 1e-9:
        s = f"**{s}**"
    return f"{s:>9}"

for fz in fuzzers:
    cells = []
    for subj in subjects:
        for label in ("5M", "3H"):
            cells.append(fmt_cell(fz, subj, label))
    print(f"| {fz:<12} | " + " | ".join(cells) + " |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
