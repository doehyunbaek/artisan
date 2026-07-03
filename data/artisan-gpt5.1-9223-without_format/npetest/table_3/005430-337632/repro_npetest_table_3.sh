#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   29 |       16 |         6 |       4 |     4 |    59 |
|        | NPETest  |   37 |       19 |         6 |       6 |     4 |    72 |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact

# Section 3: Reproduction commands (populate from reviewed steps)
# Convert rq1_result.xlsx to CSV
uvx --from csvkit in2csv NPETestArtifact/rq1_result.xlsx > /workspace/rq1.csv

# Compute per-benchmark unique NPE counts for EvoSuite and NPETest (with Bears-70 excluded)
python - << 'PY' > /workspace/repro.txt
import csv
from collections import defaultdict

csv_path = "/workspace/rq1.csv"
benchmarks = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]
tools = ["evosuite", "npetest"]

counts = defaultdict(lambda: {t: 0 for t in tools})

with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        bench = (row.get("a") or "").strip()
        proj = (row.get("b") or "").strip()
        if bench not in benchmarks or not proj:
            continue
        # Exclude Bears-70 to mirror the final paper's dataset
        if bench == "Bears" and proj == "Bears-70":
            continue
        for t in tools:
            val = (row.get(t) or "").strip()
            if not val:
                continue
            try:
                if float(val) > 0.0:
                    counts[bench][t] += 1
            except ValueError:
                pass

totals = {t: 0 for t in tools}
for b in benchmarks:
    for t in tools:
        totals[t] += counts[b][t]

def c(bench, tool):
    return counts.get(bench, {}).get(tool, 0)

print("**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**")
print()
print("| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |")
print("| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |")
print(f"| 5 min  | EvoSuite | {c('NPEX','evosuite'):4d} | {c('BugSwarm','evosuite'):7d} | {c('Defects4J','evosuite'):9d} | {c('Genesis','evosuite'):7d} | {c('Bears','evosuite'):5d} | {totals['evosuite']:5d} |")
print(f"|        | NPETest  | {c('NPEX','npetest'):4d} | {c('BugSwarm','npetest'):7d} | {c('Defects4J','npetest'):9d} | {c('Genesis','npetest'):7d} | {c('Bears','npetest'):5d} | {totals['npetest']:5d} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
