#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   29 |       16 |         6 |       4 |     4 |    59 |
|        | NPETest  |   37 |       19 |         6 |       6 |     6 |    74 |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -d NPETestArtifact ]; then
  git clone https://github.com/kupl/NPETestArtifact.git
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NPETestArtifact

# Convert RQ1 Excel results to CSV for easier processing
uvx --from csvkit in2csv rq1_result.xlsx > rq1_result.csv

# Compute the per-benchmark counts and emit a markdown table
python - << 'PY' > /workspace/repro.txt
import pandas as pd

# Load converted CSV and normalize column names
df = pd.read_csv('/workspace/NPETestArtifact/rq1_result.csv')
df = df.rename(columns={'a': 'Benchmark', 'b': 'Project'})

benchmarks = ['NPEX', 'BugSwarm', 'Defects4J', 'Genesis', 'Bears']
tools = ['evosuite', 'npetest']

counts = {bench: {} for bench in benchmarks}
Totals = {tool: 0 for tool in tools}

for bench in benchmarks:
    sub = df[df['Benchmark'] == bench]
    for tool in tools:
        n = int((sub[tool] > 0).sum())
        counts[bench][tool] = n
        Totals[tool] += n

lines = []
lines.append('**Reproduced Table 3: Unique NPEs detected at 5-minute budget.**\\n')
lines.append('')
lines.append('| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |')
lines.append('| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |')

def row(tool_key, label):
    vals = [counts[b][tool_key] for b in benchmarks]
    total = Totals[tool_key]
    return f"| 5 min  | {label:<8} | {vals[0]:3d} | {vals[1]:7d} | {vals[2]:8d} | {vals[3]:6d} | {vals[4]:4d} | {total:4d} |"

lines.append(row('evosuite', 'EvoSuite'))
lines.append(row('npetest', 'NPETest'))

print('\n'.join(lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
