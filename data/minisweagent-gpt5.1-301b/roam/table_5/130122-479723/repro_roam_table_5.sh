#!/usr/bin/bash
set -euo pipefail

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
  curl -L 'https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content' -o ROAM-Artifact.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
mkdir -p /workspace/artifact
if [ ! -d /workspace/artifact/ROAM-Artifact ]; then
  unzip -q ROAM-Artifact.zip -d /workspace/artifact
fi

cd /workspace/artifact/ROAM-Artifact/Evaluation

# Convert the provided results PDF into Markdown for parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' results.pdf > results.md

# Compute Roam, Roam-Sim, and Roam-Dist metrics and write them to /workspace/repro.txt and a Markdown table
python << 'PY'
from pathlib import Path

def parse_table(path):
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.startswith("|"):
                continue
            cells = [c.strip() for c in line.split("|")]
            rows.append(cells)
    return rows

rows = parse_table("results.md")
# rows[0]: column group names; rows[1]: separator; rows[2]: header labels; data starts at rows[3]
data_rows = rows[3:]

def aggregate(idx_ma, idx_rr):
    ma_vals = []
    rr_vals = []
    for r in data_rows:
        if len(r) <= max(idx_ma, idx_rr):
            continue
        ma = r[idx_ma].strip()
        rr = r[idx_rr].strip().lower()
        if ma:
            try:
                ma_vals.append(float(ma))
            except ValueError:
                pass
        if rr:
            rr_vals.append(1 if rr == "success" else 0)
    avg_ma = sum(ma_vals) / len(ma_vals)
    repro_rate = sum(rr_vals) / len(rr_vals)
    return round(avg_ma * 100), round(repro_rate * 100)

metrics = {
    "Roam":      aggregate(7, 8),   # Roam Match Accuracy & Reproduction Result
    "Roam-Sim":  aggregate(13, 14), # Roam-Sim Match Accuracy & Reproduction Result
    "Roam-Dist": aggregate(16, 17), # Roam-Dist Match Accuracy & Reproduction Result
}

repro_path = Path("/workspace/repro.txt")
table_path = Path("/workspace/repro_table.md")

# Write raw numeric results
with repro_path.open("w", encoding="utf-8") as f:
    for name in ["Roam-Sim", "Roam-Dist", "Roam"]:
        ma, rr = metrics[name]
        f.write(f"{name} {ma} {rr}\n")

# Write formatted Markdown table for submission
with table_path.open("w", encoding="utf-8") as f:
    f.write("**Table 5: The Match Accuracy and Reproduction Rate for RQ5**\n\n")
    f.write("|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |\n")
    f.write("| --------- | :---------------------: | :-------------------: |\n")
    for name in ["Roam-Sim", "Roam-Dist", "Roam"]:
        ma, rr = metrics[name]
        f.write(f"| {name:<9} | {ma:^23} | {rr:^19} |\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro_table.md
echo '</artisan_submit>'
