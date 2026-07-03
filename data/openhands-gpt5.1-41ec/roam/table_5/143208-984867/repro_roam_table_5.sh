#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: The Match Accuracy and Reproduction Rate for RQ5**

|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |
| --------- | :---------------------: | :-------------------: |
| Roam-Sim  |            88           |           65          |
| Roam-Dist |            77           |           38          |
| Roam      |            93           |           94          |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f ROAM-Artifact.zip ]; then
  curl -L "https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content" -o ROAM-Artifact.zip
fi
if [ ! -d ROAM-Artifact ]; then
  unzip -o ROAM-Artifact.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the detailed results PDF to markdown for parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' \
  ROAM-Artifact/Evaluation/results.pdf > /workspace/results_md.txt

# Parse the markdown table to compute averages and reproduction rates
python - << 'EOF_PY'
from statistics import mean

rows = []
with open('/workspace/results_md.txt', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line.startswith('|'):
            continue
        parts = line.split('|')
        if len(parts) < 10:
            continue
        idx = parts[1].strip()
        if not idx.isdigit():
            continue
        rows.append(parts)

if len(rows) != 72:
    raise SystemExit(f"Expected 72 data rows, got {len(rows)}")

# Column mapping (indices in parts list):
# 0: ''
# 1: row index
# 2: issue id
# 3: link
# 4: # actual steps
# 5: # provided steps
# 6: # missing steps
# 7: Roam match accuracy
# 8: Roam reproduction result
# 9: Roam running time
# 10: Roam PRM construction time
# 11: Roam event search time
# 12: Roam path recovery & execution time
# 13: Roam-Sim match accuracy
# 14: Roam-Sim reproduction result
# 15: Roam-Sim running time
# 16: Roam-Dist match accuracy
# 17: Roam-Dist reproduction result
# 18: Roam-Dist running time

def parse_float(x: str):
    x = x.strip()
    if not x:
        return None
    try:
        return float(x)
    except ValueError:
        return None


def aggregate(ma_col: int, rr_col: int):
    ma_vals = []
    success = 0
    total = 0
    for parts in rows:
        ma = parse_float(parts[ma_col])
        if ma is not None:
            ma_vals.append(ma)
        result = parts[rr_col].strip().lower()
        if result:
            total += 1
            if result == 'success':
                success += 1
    avg_ma = mean(ma_vals) * 100.0
    repro_rate = success / total * 100.0 if total else 0.0
    return avg_ma, repro_rate

metrics = {}
metrics['Roam'], metrics['Roam_RR'] = aggregate(7, 8)
metrics['Roam-Sim'], metrics['Roam-Sim_RR'] = aggregate(13, 14)
metrics['Roam-Dist'], metrics['Roam-Dist_RR'] = aggregate(16, 17)

with open('/workspace/repro.txt', 'w', encoding='utf-8') as out:
    out.write('Approach,AvgMatchAccuracy,ReproductionRate\n')
    out.write(f"Roam-Sim,{metrics['Roam-Sim']:.2f},{metrics['Roam-Sim_RR']:.2f}\n")
    out.write(f"Roam-Dist,{metrics['Roam-Dist']:.2f},{metrics['Roam-Dist_RR']:.2f}\n")
    out.write(f"Roam,{metrics['Roam']:.2f},{metrics['Roam_RR']:.2f}\n")
EOF_PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'EOF_PY'
import csv
from pathlib import Path

repro_path = Path('/workspace/repro.txt')
rows = []
with repro_path.open() as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

# Ensure ordering matches the paper's Table 5
order = ['Roam-Sim', 'Roam-Dist', 'Roam']

print('**Table 5: The Match Accuracy and Reproduction Rate for RQ5**\n')
print('|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |')
print('| --------- | :---------------------: | :-------------------: |')
for name in order:
    r = next(row for row in rows if row['Approach'] == name)
    ma = round(float(r['AvgMatchAccuracy']))
    rr = round(float(r['ReproductionRate']))
    print(f"| {name:<9}|            {ma:<3}          |          {rr:<3}          |")
EOF_PY
echo '</artisan_submit>'
