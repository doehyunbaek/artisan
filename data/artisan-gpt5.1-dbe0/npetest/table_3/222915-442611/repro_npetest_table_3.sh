#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   ?? |       ?? |         ? |       ? |     ? |    ?? |
|        | NPETest  |   ?? |       ?? |         ? |       ? |     ? |    ?? |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NPETestArtifact
# Convert the "npedetection (2)" worksheet to CSV
uvx --from csvkit in2csv rq2_result.xlsx --sheet "npedetection (2)" > /workspace/npedetection.csv
# Use Python to count, for each benchmark group, how many NPEs are detected (value > 0) by each tool
python - <<'PY'
import csv
from collections import defaultdict

csv_path = "/workspace/npedetection.csv"
groups = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]
tools = ["EvoSuite", "NPETest"]
tool_cols = {"EvoSuite": "evosuite", "NPETest": "npetest"}

counts = {tool: defaultdict(int) for tool in tools}

with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        grp = (row.get("a") or "").strip()
        if grp not in groups:
            continue
        for tool in tools:
            col = tool_cols[tool]
            val_str = (row.get(col) or "").strip()
            try:
                val = float(val_str)
            except ValueError:
                val = 0.0
            if val > 0.0:
                counts[tool][grp] += 1
                counts[tool]["Total"] += 1

out_path = "/workspace/repro.txt"
with open(out_path, "w") as out:
    out.write("**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**\n\n")
    out.write("| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |\n")
    out.write("| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |\n")
    for tool in tools:
        time = "5 min" if tool == "EvoSuite" else ""
        c = counts[tool]
        line = (
            f"| {time} | {tool} | "
            f"{int(c.get('NPEX', 0))} | "
            f"{int(c.get('BugSwarm', 0))} | "
            f"{int(c.get('Defects4J', 0))} | "
            f"{int(c.get('Genesis', 0))} | "
            f"{int(c.get('Bears', 0))} | "
            f"{int(c.get('Total', 0))} |\n"
        )
        out.write(line)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
