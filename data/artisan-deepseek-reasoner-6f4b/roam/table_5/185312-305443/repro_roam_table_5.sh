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
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert results.pdf to markdown and compute averages for Table 5
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /tmp/results.md
cat > /tmp/compute.py <<'PYEOF'
import sys, re
with open('/tmp/results.md', 'r', encoding='utf-8') as f:
    lines = f.readlines()
data_rows = []
for line in lines:
    line = line.strip()
    if line.startswith('|') and '|' in line:
        parts = [p.strip() for p in line.split('|') if p.strip() != '']
        if len(parts) > 0 and parts[0].isdigit():
            data_rows.append(parts)
roam_match, roam_repro = [], []
sim_match, sim_repro = [], []
dist_match, dist_repro = [], []
for row in data_rows:
    if len(row) < 17:
        continue
    try:
        roam_match.append(float(row[6]) if row[6] else 0.0)
        sim_match.append(float(row[12]) if row[12] else 0.0)
        dist_match.append(float(row[15]) if row[15] else 0.0)
    except ValueError:
        continue
    roam_repro.append(1 if row[7].strip().lower() == 'success' else 0)
    sim_repro.append(1 if row[13].strip().lower() == 'success' else 0)
    dist_repro.append(1 if row[16].strip().lower() == 'success' else 0)
def avg(lst): return sum(lst)/len(lst)*100 if lst else 0.0
roam_avg_match = avg(roam_match)
roam_avg_repro = avg(roam_repro)
sim_avg_match = avg(sim_match)
sim_avg_repro = avg(sim_repro)
dist_avg_match = avg(dist_match)
dist_avg_repro = avg(dist_repro)
# Round to nearest integer
roam_avg_match = int(round(roam_avg_match))
roam_avg_repro = int(round(roam_avg_repro))
sim_avg_match = int(round(sim_avg_match))
sim_avg_repro = int(round(sim_avg_repro))
dist_avg_match = int(round(dist_avg_match))
dist_avg_repro = int(round(dist_avg_repro))
# Write the table to repro.txt
with open('/workspace/repro.txt', 'w') as f:
    f.write("**Table 5: The Match Accuracy and Reproduction Rate for RQ5**\n\n")
    f.write("|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |\n")
    f.write("| --------- | :---------------------: | :-------------------: |\n")
    f.write(f"| Roam-Sim  |            {sim_avg_match}           |          {sim_avg_repro}          |\n")
    f.write(f"| Roam-Dist |            {dist_avg_match}           |          {dist_avg_repro}          |\n")
    f.write(f"| Roam      |            {roam_avg_match}           |          {roam_avg_repro}          |\n")
PYEOF
python3 /tmp/compute.py
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
