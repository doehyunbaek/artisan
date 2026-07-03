#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   28 |       11 |         5 |       4 |     4 |    52 |
|        | NPETest  |   33 |       13 |         5 |       6 |     5 |    62 |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert rq1_result.xlsx to CSV
uvx --from csvkit in2csv /workspace/NPETestArtifact/rq1_result.xlsx > /workspace/rq1.csv
# Aggregate counts of unique projects with NPEs per benchmark and tool, and render Table 3
python - << 'PY' > /workspace/repro.txt
import csv

csv_path = "/workspace/rq1.csv"
benchmarks = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]
tools = ["evosuite", "npetest"]
tool_pretty = {"evosuite": "EvoSuite", "npetest": "NPETest"}

# benchmark -> tool -> set(projects with any NPE detected, i.e., percentage > 0)
hits = {b: {t: set() for t in tools} for b in benchmarks}

with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        bench = (row.get("a") or "").strip()
        proj = (row.get("b") or "").strip()
        if bench not in benchmarks or not proj:
            continue
        for t in tools:
            val = row.get(t)
            if val is None or val == "":
                continue
            try:
                v = float(val)
            except ValueError:
                continue
            if v > 0:
                hits[bench][t].add(proj)

# Compute totals per tool
totals = {t: 0 for t in tools}
for b in benchmarks:
    for t in tools:
        totals[t] += len(hits[b][t])

# Emit markdown table matching the expected format
print("**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**\n")
print("| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |")
print("| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |")

for idx, t in enumerate(tools):
    time_label = "5 min" if idx == 0 else ""
    npex = len(hits["NPEX"][t])
    bugswarm = len(hits["BugSwarm"][t])
    defects = len(hits["Defects4J"][t])
    genesis = len(hits["Genesis"][t])
    bears = len(hits["Bears"][t])
    total = totals[t]
    print(f"| {time_label:6} | {tool_pretty[t]:8} | {npex:3} | {bugswarm:7} | {defects:8} | {genesis:6} | {bears:4} | {total:4} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
