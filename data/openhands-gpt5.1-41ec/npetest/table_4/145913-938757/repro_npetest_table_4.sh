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
cd /workspace
if [ ! -d NPETestArtifact ]; then
  git clone https://github.com/kupl/NPETestArtifact.git
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Compute Table 4 values from rq2_result.xlsx and write to /workspace/repro.txt
python - << 'EOPY'
import openpyxl
from collections import defaultdict
from pathlib import Path

root = Path('/workspace/NPETestArtifact')
wb = openpyxl.load_workbook(root / 'rq2_result.xlsx', data_only=True)
ws = wb['npedetection (2)']

IDX_EVO = 5
IDX_EVO_DEF = 6
DATASETS = ('NPEX', 'BugSwarm', 'Defects4J', 'Genesis', 'Bears')

stats = defaultdict(lambda: {'evo_sum': 0.0, 'def_sum': 0.0, 'count': 0})

for row in ws.iter_rows(min_row=2, values_only=True):
    ds = row[0]
    if ds not in DATASETS:
        continue
    evo = row[IDX_EVO]
    evodef = row[IDX_EVO_DEF]
    if evo is None or evodef is None:
        continue
    s = stats[ds]
    s['evo_sum'] += evo
    s['def_sum'] += evodef
    s['count'] += 1

# compute per-dataset means
means_evo = {}
means_def = {}

total_evo_sum = total_def_sum = total_count = 0
for ds in DATASETS:
    v = stats[ds]
    mean_evo = v['evo_sum'] / v['count']
    mean_def = v['def_sum'] / v['count']
    means_evo[ds] = round(mean_evo, 1)
    means_def[ds] = round(mean_def, 1)
    total_evo_sum += v['evo_sum']
    total_def_sum += v['def_sum']
    total_count += v['count']

means_evo['Total'] = round(total_evo_sum / total_count, 1)
means_def['Total'] = round(total_def_sum / total_count, 1)

order = ['NPEX', 'BugSwarm', 'Defects4J', 'Genesis', 'Bears', 'Total']

out = Path('/workspace/repro.txt')
with out.open('w') as f:
    f.write('**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**\n\n')
    f.write('| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |\n')
    f.write('| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |\n')
    def fmt_row(label, values):
        cells = [f"{values[d]:.1f}%".rjust(6) for d in order]
        return f"| {label:<14}| " + " | ".join(cells) + " |\n"

    f.write(fmt_row('EvoSuite', means_evo))
    f.write(fmt_row('EvoSuite_{Def}', means_def))
EOPY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
