#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   29 |       16 |         6 |       4 |     4 |    59 |
|        | NPETest  |   37 |       19 |         6 |       6 |     5 |    73 |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NPETestArtifact
uvx --from csvkit in2csv rq1_result.xlsx > /workspace/rq1.csv
python - << 'PY' > /workspace/repro.txt
import csv, collections

path = "/workspace/rq1.csv"
with open(path, newline="") as f:
    reader = csv.DictReader(f)
    datasets = ["NPEX","BugSwarm","Defects4J","Genesis","Bears"]
    counts = {tool: collections.Counter() for tool in ["evosuite","npetest"]}
    for row in reader:
        ds = (row.get("a") or "").strip()
        if ds not in datasets:
            continue
        for tool in counts:
            val = (row.get(tool) or "").strip()
            if not val:
                continue
            try:
                v = float(val)
            except ValueError:
                continue
            if v > 0.0:
                counts[tool][ds] += 1

totals = {tool: sum(counts[tool][ds] for ds in datasets) for tool in counts}

print("**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**")
print()
print("| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |")
print("| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |")

for label, key in [("EvoSuite", "evosuite"), ("NPETest", "npetest")]:
    time = "5 min" if label == "EvoSuite" else ""
    npex = counts[key]["NPEX"]
    bugs = counts[key]["BugSwarm"]
    d4j  = counts[key]["Defects4J"]
    gen  = counts[key]["Genesis"]
    bears = counts[key]["Bears"]
    total = totals[key]
    print(f"| {time:6} | {label:8} | {npex:4} | {bugs:8} | {d4j:9} | {gen:7} | {bears:5} | {total:5} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
