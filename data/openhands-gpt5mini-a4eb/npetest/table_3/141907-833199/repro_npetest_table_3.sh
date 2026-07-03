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
# Clone the artifact repository if not already present
if [ ! -d "/workspace/NPETestArtifact" ]; then
  git clone https://github.com/kupl/NPETestArtifact.git /workspace/NPETestArtifact
else
  echo "NPETestArtifact already present, skipping clone."
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Convert provided rq1_result.xlsx to CSV and compute the table by counting detected NPE rows.
# The script will write results to /workspace/repro.txt

# Convert the first sheet of rq1_result.xlsx to CSV (requires uvx/in2csv available in environment)
uvx --from csvkit in2csv /workspace/NPETestArtifact/rq1_result.xlsx > /workspace/rq1_sheet.csv || true

python3 - << 'PY' > /workspace/repro.txt
import csv
from collections import defaultdict

input_csv = '/workspace/rq1_sheet.csv'
count_ev = defaultdict(int)
count_np = defaultdict(int)
with open(input_csv,'r',newline='') as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        if not any(row):
            continue
        benchmark = row[0].strip()
        if benchmark=='' and row[-3] and row[-3].replace('.','',1).isdigit():
            continue
        if benchmark=='' and row[1]=='' and row[2]=='':
            continue
        if benchmark=='':
            continue
        try:
            evosuite = float(row[-2]) if row[-2]!='' else 0.0
        except:
            evosuite = 0.0
        try:
            npetest = float(row[-1]) if row[-1]!='' else 0.0
        except:
            npetest = 0.0
        if evosuite>0:
            count_ev[benchmark]+=1
        if npetest>0:
            count_np[benchmark]+=1

benchmarks = ['NPEX','BugSwarm','Defects4J','Genesis','Bears']
out_lines = []
for b in benchmarks:
    ev = count_ev.get(b,0)
    np = count_np.get(b,0)
    out_lines.append((b, ev, np))

total_ev = sum(x[1] for x in out_lines)
total_np = sum(x[2] for x in out_lines)

print('Reproduced Table (counting each reported NPE row where tool > 0):')
print()
print('| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |')
print('| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |')
print(f"| 5 min  | EvoSuite |   {out_lines[0][1]} |       {out_lines[1][1]} |         {out_lines[2][1]} |       {out_lines[3][1]} |     {out_lines[4][1]} |    {total_ev} |")
print(f"|        | NPETest  |   {out_lines[0][2]} |       {out_lines[1][2]} |         {out_lines[2][2]} |       {out_lines[3][2]} |     {out_lines[4][2]} |    {total_np} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'

