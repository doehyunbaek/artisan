#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      19      |        16        |          470         |  **505**  |   2,674  |  3,354 |
| **Mdn.** |       1      |         1        |          111         |  **150**  |   3,600  |  3,600 |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -d ROAM-Artifact ]; then
  curl -L -o ROAM-Artifact.zip https://zenodo.org/records/11068809/files/ROAM-Artifact.zip
  unzip -q ROAM-Artifact.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Compute the running time statistics from the provided results.pdf table.
cd /workspace/ROAM-Artifact/Evaluation
if [ ! -f results.md ]; then
  uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown("results.pdf"))' > results.md
fi

python - << 'PY' > /workspace/repro.txt
import csv, io, statistics, subprocess

# Convert dataset.xlsx/csv to CSV text
csv_text = subprocess.check_output([
    'bash','-lc',
    'cd /workspace/ROAM-Artifact/Evaluation && uvx --from csvkit in2csv dataset.csv'
], text=True)
reader = csv.DictReader(io.StringIO(csv_text))

# Map issue id to benchmark group
issue_group = {}
for row in reader:
    subj = row['Subject id']
    issue = row['Issue id']
    if subj.startswith('recdroid-'):
        issue_group[issue] = 'recdroid'
    elif subj.startswith('yakusu-'):
        issue_group[issue] = 'yakusu'
    else:
        issue_group[issue] = 'other'

# Parse the big markdown table extracted from results.pdf
rows = []
with open('/workspace/ROAM-Artifact/Evaluation/results.md') as f:
    for line in f:
        if line.startswith('|'):
            cells = [c.strip() for c in line.strip().split('|')[1:-1]]
            rows.append(cells)

header_top = rows[0]
header = rows[2]  # skip alignment row

# Propagate logical column groups from the top header row
labels = []
current = None
for c in header_top:
    if c and not c.startswith('Col'):
        current = c
    labels.append(current)

# Locate indices for the relevant columns
idx = {}
for i,(lab,col) in enumerate(zip(labels, header)):
    if lab == 'ROAM' and col == 'PRM<br>Construction<br>Time':
        idx['roam_prm'] = i
    if lab == 'ROAM' and col == 'Event<br>Search<br>Time':
        idx['roam_event'] = i
    if lab == 'ROAM' and col == 'Path<br>Recovery<br>and<br>Execution<br>Time':
        idx['roam_path'] = i
    if lab == 'ReCDroid' and col == 'Running<br>Time':
        idx['recdroid_rt'] = i
    if lab == 'Yakusu' and col == 'Running<br>Time':
        idx['yakusu_rt'] = i

# Collect per-issue values
roam_prm, roam_event, roam_path = [], [], []
recdroid_rt, yakusu_rt = [], []

for row in rows[3:]:
    if not row or len(row) < 3:
        continue
    issue = row[1]
    group = issue_group.get(issue)
    # ROAM components (all issues)
    for lst, key in ((roam_prm,'roam_prm'), (roam_event,'roam_event'), (roam_path,'roam_path')):
        col_idx = idx[key]
        if col_idx < len(row):
            v = row[col_idx]
            try:
                lst.append(float(v))
            except ValueError:
                pass
    # Baseline running times, by group
    if group == 'recdroid':
        col_idx = idx['recdroid_rt']
        if col_idx < len(row):
            v = row[col_idx]
            try:
                recdroid_rt.append(float(v))
            except ValueError:
                pass
    if group == 'yakusu':
        col_idx = idx['yakusu_rt']
        if col_idx < len(row):
            v = row[col_idx]
            try:
                yakusu_rt.append(float(v))
            except ValueError:
                pass

# Helper to format mean/median rounded to nearest integer
rnd = lambda x: int(round(x))

roam_prm_avg, roam_prm_mdn = rnd(sum(roam_prm)/len(roam_prm)), rnd(statistics.median(roam_prm))
roam_evt_avg, roam_evt_mdn = rnd(sum(roam_event)/len(roam_event)), rnd(statistics.median(roam_event))
roam_pth_avg, roam_pth_mdn = rnd(sum(roam_path)/len(roam_path)), rnd(statistics.median(roam_path))

roam_tot_avg = roam_prm_avg + roam_evt_avg + roam_pth_avg
roam_tot_mdn = roam_prm_mdn + roam_evt_mdn + roam_pth_mdn

recdroid_avg, recdroid_mdn = rnd(sum(recdroid_rt)/len(recdroid_rt)), rnd(statistics.median(recdroid_rt))
yakusu_avg, yakusu_mdn = rnd(sum(yakusu_rt)/len(yakusu_rt)), rnd(statistics.median(yakusu_rt))

print('**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**\n')
print('|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |')
print('| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |')
print('|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |')
print(f"| **Avg.** | {roam_prm_avg:8d} | {roam_evt_avg:8d} | {roam_pth_avg:12d} | {roam_tot_avg:7d} | {recdroid_avg:7d} | {yakusu_avg:6d} |")
print(f"| **Mdn.** | {roam_prm_mdn:8d} | {roam_evt_mdn:8d} | {roam_pth_mdn:12d} | {roam_tot_mdn:7d} | {recdroid_mdn:7d} | {yakusu_mdn:6d} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
