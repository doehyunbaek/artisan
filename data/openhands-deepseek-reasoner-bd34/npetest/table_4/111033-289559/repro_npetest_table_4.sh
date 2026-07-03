#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 50.7% |    68.0% |     64.7% |   47.3% | 64.0% | 56.9% |
| EvoSuite_{Def} | 48.8% |    62.7% |     83.3% |   45.3% | 60.0% | 55.7% |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact..."
cd /workspace
if [ ! -d "NPETestArtifact" ]; then
    git clone https://github.com/kupl/NPETestArtifact.git
fi
cd NPETestArtifact
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Reproducing Table 4 from raw data..."
cat > /workspace/NPETestArtifact/reproduce_table4.py <<'PYSCRIPT'
import openpyxl
from collections import defaultdict

wb = openpyxl.load_workbook('rq2_result.xlsx', data_only=True)
ws = wb['npedetection (2)']

col_dataset = 0
col_evosuite = 5
col_evosuite_def = 6

data = defaultdict(list)

for row in ws.iter_rows(min_row=2, values_only=True):
    dataset = row[col_dataset]
    if dataset is None:
        continue
    evo = row[col_evosuite]
    evo_def = row[col_evosuite_def]
    if evo is None or evo_def is None:
        continue
    data[dataset].append((evo, evo_def))

# compute averages per dataset
averages = {}
for dataset, values in data.items():
    n = len(values)
    avg_evo = sum(v[0] for v in values) / n
    avg_evo_def = sum(v[1] for v in values) / n
    averages[dataset] = (avg_evo, avg_evo_def, n)

# total across all benchmarks
total_evo_sum = sum(sum(v[0] for v in values) for values in data.values())
total_evo_def_sum = sum(sum(v[1] for v in values) for values in data.values())
total_n = sum(len(values) for values in data.values())
total_avg_evo = total_evo_sum / total_n
total_avg_evo_def = total_evo_def_sum / total_n
averages['Total'] = (total_avg_evo, total_avg_evo_def, total_n)

def fmt(x):
    return f"{x:.1f}%"

evo_vals = [averages['NPEX'][0], averages['BugSwarm'][0], averages['Defects4J'][0], averages['Genesis'][0], averages['Bears'][0], averages['Total'][0]]
evo_def_vals = [averages['NPEX'][1], averages['BugSwarm'][1], averages['Defects4J'][1], averages['Genesis'][1], averages['Bears'][1], averages['Total'][1]]

with open('/workspace/repro.txt', 'w') as f:
    f.write("**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**\n\n")
    f.write("| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |\n")
    f.write("| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |\n")
    f.write(f"| EvoSuite       | {fmt(evo_vals[0])} |    {fmt(evo_vals[1])} |     {fmt(evo_vals[2])} |   {fmt(evo_vals[3])} |  {fmt(evo_vals[4])} | {fmt(evo_vals[5])} |\n")
    f.write(f"| EvoSuite_{{Def}} | {fmt(evo_def_vals[0])} |    {fmt(evo_def_vals[1])} |     {fmt(evo_def_vals[2])} |   {fmt(evo_def_vals[3])} |  {fmt(evo_def_vals[4])} | {fmt(evo_def_vals[5])} |\n")
PYSCRIPT

python3 /workspace/NPETestArtifact/reproduce_table4.py
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'