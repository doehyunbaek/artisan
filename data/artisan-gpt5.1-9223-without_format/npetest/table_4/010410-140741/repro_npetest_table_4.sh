#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | ??.?% |    ??.?% |     ??.?% |   ??.?% | ??.?% | ??.?% |
| EvoSuite_{Def} | ??.?% |    ??.?% |     ??.?% |   ??.?% | ??.?% | ??.?% |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NPETestArtifact
uvx --from openpyxl python - << 'PY'
from openpyxl import load_workbook
from collections import defaultdict

wb = load_workbook("rq2_result.xlsx", data_only=True)
ws = wb["npedetection (2)"]

rows = list(ws.iter_rows(values_only=True))
header = rows[0]

ev_idx = header.index("evosuite")
ev_def_idx = header.index("evosuite_def")

suites = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears"]

acc = {
    "EvoSuite": {s: [] for s in suites},
    "EvoSuite_{Def}": {s: [] for s in suites},
}

for r in rows[1:]:
    suite = r[0]
    if suite not in suites:
        continue
    ev = r[ev_idx]
    ev_def = r[ev_def_idx]
    if isinstance(ev, (int, float)):
        acc["EvoSuite"][suite].append(ev)
    if isinstance(ev_def, (int, float)):
        acc["EvoSuite_{Def}"][suite].append(ev_def)

def avg(vals):
    return sum(vals) / len(vals) if vals else 0.0

def fmt(x):
    return f"{x:.1f}%"

results = {}
for tool in acc:
    tool_vals = []
    suite_vals = {}
    for s in suites:
        v = avg(acc[tool][s])
        suite_vals[s] = v
        tool_vals.extend(acc[tool][s])
    suite_vals["Total"] = avg(tool_vals)
    results[tool] = suite_vals

order = ["NPEX", "BugSwarm", "Defects4J", "Genesis", "Bears", "Total"]

lines = []
for tool in ("EvoSuite", "EvoSuite_{Def}"):
    vals = [fmt(results[tool][k]) for k in order]
    line = "| {tool:<13} | ".format(tool=tool) + " | ".join(f"{v:>6}" for v in vals) + " |"
    lines.append(line)

header_md = """**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |"""

content = header_md + "\n" + "\n".join(lines) + "\n"

with open("/workspace/repro.txt", "w", encoding="utf-8") as f:
    f.write(content)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
