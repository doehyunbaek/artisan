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
curl -L 'https://zenodo.org/records/11068809/files/ROAM-Artifact.zip' -o ROAM-Artifact.zip
unzip -o ROAM-Artifact.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# We use the provided Evaluation/results.pdf (converted to Markdown) to compute
# the averages underlying Table 5.
cd /workspace/ROAM-Artifact/Evaluation
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; open("results.md","w").write(p.to_markdown(sys.argv[1]))' results.pdf
python - << 'PY'
import statistics

rows = []
with open('results.md', 'r') as f:
    for line in f:
        if not line.startswith('|'):
            continue
        parts = [p.strip() for p in line.strip().split('|')[1:-1]]
        if not parts or parts[0] == '' or parts[0] == 'Col1' or parts[0] == '---':
            continue
        if parts[0].isdigit():
            rows.append(parts)

idx_roam_match = 6
idx_roam_repro = 7
idx_roamsim_match = 12
idx_roamsim_repro = 13
idx_roamdist_match = 15
idx_roamdist_repro = 16


def avg_match(idx):
    vals = []
    for r in rows:
        v = r[idx]
        if not v:
            continue
        try:
            vals.append(float(v))
        except ValueError:
            pass
    return statistics.mean(vals) * 100


def repro_rate(idx):
    succ = 0
    total = 0
    for r in rows:
        v = r[idx]
        if v in ('success', 'failure', 'false positive'):
            total += 1
            if v == 'success':
                succ += 1
    return succ / total * 100

roam_sim_match = avg_match(idx_roamsim_match)
roam_sim_repro = repro_rate(idx_roamsim_repro)
roam_dist_match = avg_match(idx_roamdist_match)
roam_dist_repro = repro_rate(idx_roamdist_repro)
roam_match = avg_match(idx_roam_match)
roam_repro = repro_rate(idx_roam_repro)

with open('/workspace/repro.txt', 'w') as out:
    out.write('**Table 5: The Match Accuracy and Reproduction Rate for RQ5**\n\n')
    out.write('|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |\n')
    out.write('| --------- | :---------------------: | :-------------------: |\n')
    out.write(f"| Roam-Sim  | {roam_sim_match:.0f} | {roam_sim_repro:.0f} |\n")
    out.write(f"| Roam-Dist | {roam_dist_match:.0f} | {roam_dist_repro:.0f} |\n")
    out.write(f"| Roam      | {roam_match:.0f} | {roam_repro:.0f} |\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
