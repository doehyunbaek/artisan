#!/usr/bin/bash
set -euo pipefail

# Always operate from this script's directory (expected to be /workspace)
cd "$(dirname "$0")"

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**

| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |
| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |
| Ant     |     0.561 |     0.923 |        0.459 |        0.124 |        0.493 |        0.069 |
| BCEL    |     0.000 |     0.000 |        0.000 |        0.000 |        0.000 |        0.000 |
| Closure |     0.742 |     0.717 |        0.661 |        0.101 |        0.712 |        0.094 |
| Maven   |     0.446 |     0.589 |        0.404 |        0.497 |        0.399 |        0.453 |
| Nashorn |     0.622 |     0.646 |        0.548 |        0.117 |        0.591 |        0.132 |
| Rhino   |     0.611 |     0.502 |        0.599 |        0.263 |        0.643 |        0.255 |
| Tomcat  |     0.322 |     0.775 |        0.350 |        0.276 |        0.328 |        0.279 |

EOTABLE

# Section 2: Artifact download
# This fetches heritability.csv and other data files into the current directory.
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Section 3: Reproduction commands
# Compute HY (hybrid proportion) and IR (median inheritance_rate) from heritability.csv
python3 - << 'PY' > /workspace/repro.txt
import csv
import statistics
from collections import defaultdict

subjects = ["Ant", "BCEL", "Closure", "Maven", "Nashorn", "Rhino", "Tomcat"]
ops = ["Linked", "One Point", "Two Point"]

# data[subject][op] = list of rows
data = defaultdict(lambda: defaultdict(list))

with open("heritability.csv", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        s = row["subject"]
        o = row["crossover_operator"]
        if s in subjects and o in ops:
            data[s][o].append(row)

def metrics(rows):
    if not rows:
        return 0.0, 0.0
    n = len(rows)
    hy = sum(1 for r in rows if r["hybrid"].lower() == "true") / n
    ir_vals = [float(r["inheritance_rate"]) for r in rows]
    ir = statistics.median(ir_vals)
    return hy, ir

print("**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**")
print()
print("| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |")
print("| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |")

for s in subjects:
    linked_hy, linked_ir = metrics(data[s]["Linked"])
    one_hy, one_ir = metrics(data[s]["One Point"])
    two_hy, two_ir = metrics(data[s]["Two Point"])
    # Format with three decimal places to match the paper
    print(f"| {s:<7} | {linked_hy:9.3f} | {linked_ir:9.3f} | {one_hy:11.3f} | {one_ir:11.3f} | {two_hy:11.3f} | {two_ir:11.3f} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
