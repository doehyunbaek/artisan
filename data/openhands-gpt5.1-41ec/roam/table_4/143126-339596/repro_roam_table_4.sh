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
curl -L 'https://zenodo.org/api/records/11068809' -o record.json
curl -L 'https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content' -o ROAM-Artifact.zip
python -m zipfile -e ROAM-Artifact.zip .

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ROAM-Artifact
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown("Evaluation/results.pdf"))' > Evaluation/results.md

python - << 'PY'
import statistics as stats
from math import floor

# Load table converted from Evaluation/results.pdf
with open('Evaluation/results.md') as f:
    lines = f.readlines()

rows = []
for line in lines[4:]:
    line = line.strip()
    if not line or not line.startswith('|'):
        continue
    cols = [c.strip() for c in line.split('|')]
    if cols[1] == '':
        continue
    rows.append(cols)

indices = {
    'ROAM_prm': 10,
    'ROAM_event': 11,
    'ROAM_path': 12,
    'ROAM_total': 9,
    'ReCDroid': 24,
    'Yakusu': 56,
}

def round_half_up(x: float) -> int:
    return int(floor(x + 0.5))

metrics = {}
for name, idx in indices.items():
    vals = [float(r[idx]) for r in rows if r[idx]]
    avg = sum(vals) / len(vals)
    med = stats.median(vals)
    metrics[name] = (round_half_up(avg), round_half_up(med))

(avg_prm, med_prm) = metrics['ROAM_prm']
(avg_event, med_event) = metrics['ROAM_event']
(avg_path, med_path) = metrics['ROAM_path']
(avg_total, med_total) = metrics['ROAM_total']
(avg_rec, med_rec) = metrics['ReCDroid']
(avg_yak, med_yak) = metrics['Yakusu']

with open('/workspace/repro.txt', 'w') as out:
    out.write("""**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**\n\n""")
    out.write("""|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |\n""")
    out.write("""| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |\n""")
    out.write("""|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |\n""")

    out.write(f"| **Avg.** |      {avg_prm}      |        {avg_event}        |          {avg_path}         |  **{avg_total}**  |   {avg_rec:,}  |  {avg_yak:,} |\n")
    out.write(f"| **Mdn.** |       {med_prm}      |         {med_event}        |          {med_path}         |  **{med_total}**  |   {med_rec:,}  |  {med_yak:,} |\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
