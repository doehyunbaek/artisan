#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      ??      |        ??        |          ???         |  **???**  |   ?,???  |  ?,??? |
| **Mdn.** |       ?      |         ?        |          ???         |  **???**  |   ?,???  |  ?,??? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809

# Generate results.md from results.pdf so we can parse the detailed per-subject table
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > ROAM-Artifact/ROAM-Artifact/Evaluation/results.md

# Section 3: Reproduction commands (compute averages/medians into /workspace/repro.txt)
python - <<'PY' > /workspace/repro.txt
from pathlib import Path
import statistics as stats

def split_row(line):
    return line.strip().strip('|').split('|')

lines = Path("ROAM-Artifact/ROAM-Artifact/Evaluation/results.md").read_text().splitlines()

# Locate header
hdr_idx = None
for i, line in enumerate(lines):
    if line.startswith("|Col1|Col2|Col3|Col4|"):
        hdr_idx = i
        break
if hdr_idx is None:
    raise SystemExit("Header row not found")

group_hdr  = split_row(lines[hdr_idx])
metric_hdr = split_row(lines[hdr_idx + 2])

# Identify ROAM timing columns from the metric header
prm_idx = None
for idx, m in enumerate(metric_hdr):
    if "PRM<br>Construction<br>Time" in m:
        prm_idx = idx
        break
if prm_idx is None:
    raise SystemExit("PRM Construction column not found")

event_idx = prm_idx + 1
path_idx  = prm_idx + 2
total_idx = prm_idx - 1  # ROAM total running time

# Identify ReCDroid and Yakusu running time indices
recdroid_idx = yakusu_idx = None
for idx, (g, m) in enumerate(zip(group_hdr, metric_hdr)):
    if g.strip() == "ReCDroid" and "Running<br>Time" in m:
        recdroid_idx = idx
    if g.strip() == "Yakusu" and "Running<br>Time" in m:
        yakusu_idx = idx

if recdroid_idx is None or yakusu_idx is None:
    raise SystemExit(f"ReCDroid/Yakusu indices not found (ReCDroid={recdroid_idx}, Yakusu={yakusu_idx})")

def parse_float(s):
    s = s.strip()
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        return None

vals = {
    "ROAM_prm":   [],
    "ROAM_event": [],
    "ROAM_path":  [],
    "ROAM_total": [],
    "ReCDroid":   [],
    "Yakusu":     [],
}

# Data rows start after header (group + sep + metrics)
for line in lines[hdr_idx + 3:]:
    if not line.startswith("|"):
        break
    cells = split_row(line)
    if not cells or not cells[0].strip().isdigit():
        continue  # skip non-data rows

    # cells[0] is row index; metric index k corresponds to cells[k+1]
    def get(idx):
        if idx + 1 >= len(cells):
            return None
        return parse_float(cells[idx + 1])

    t  = get(total_idx)
    p  = get(prm_idx)
    e  = get(event_idx)
    pa = get(path_idx)
    r  = get(recdroid_idx)
    y  = get(yakusu_idx)

    if t  is not None: vals["ROAM_total"].append(t)
    if p  is not None: vals["ROAM_prm"].append(p)
    if e  is not None: vals["ROAM_event"].append(e)
    if pa is not None: vals["ROAM_path"].append(pa)
    if r  is not None: vals["ReCDroid"].append(r)
    if y  is not None: vals["Yakusu"].append(y)

def summarize(name):
    v = vals[name]
    return stats.mean(v), stats.median(v)

results = {}
for key in vals:
    avg, med = summarize(key)
    results[key] = (avg, med)

for key, (avg, med) in results.items():
    print(f"{key}: avg={avg:.2f}, med={med:.2f}")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat <<'OTABLE'
**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      19      |        16        |          470         | **505**   |  2,674   | 3,354  |
| **Mdn.** |       1      |         1        |          111         | **150**   |  3,600   | 3,600  |

OTABLE
echo '</artisan_submit>'
