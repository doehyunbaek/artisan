#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: The Match Accuracy and Reproduction Rate for RQ5**

|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |
| --------- | :---------------------: | :-------------------: |
| Roam-Sim  |            ??           |           ??          |
| Roam-Dist |            ??           |           ??          |
| Roam      |            ??           |           ??          |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ROAM-Artifact/ROAM-Artifact/Evaluation
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' results.pdf > results.md
python - <<'PY'
import pathlib, statistics

path = pathlib.Path("results.md")

rows = []
with path.open() as f:
    for line in f:
        line = line.strip()
        if not line.startswith("|"):
            continue
        parts = line.split("|")
        rows.append(parts)

# rows[0]: tool names; rows[1]: separator; rows[2]: metric labels; rows[3:]: data rows
data_rows = rows[3:]

def parse_float(x):
    try:
        return float(x)
    except Exception:
        return None

def compute_for(col_match, col_repro):
    match_vals = []
    success = 0
    total = 0
    for r in data_rows:
        if len(r) <= max(col_match, col_repro):
            continue
        m = parse_float(r[col_match])
        res = r[col_repro].strip().lower()
        if m is not None:
            match_vals.append(m)
        total += 1
        if res == "success":
            success += 1
    avg_match = statistics.mean(match_vals) if match_vals else 0.0
    repro_rate = 100.0 * success / total if total else 0.0
    return avg_match * 100.0, repro_rate

# Column indices (0-based) for metrics from the per-subject table:
# Roam:      match at 7,  reproduction result at 8
# Roam-Sim:  match at 13, reproduction result at 14
# Roam-Dist: match at 16, reproduction result at 17
metrics = {}
for name, cm, cr in [
    ("Roam", 7, 8),
    ("Roam-Sim", 13, 14),
    ("Roam-Dist", 16, 17),
]:
    metrics[name] = compute_for(cm, cr)

lines = [
    "**Table 5: The Match Accuracy and Reproduction Rate for RQ5**",
    "",
    "|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |",
    "| --------- | :---------------------: | :-------------------: |",
    f"| Roam-Sim  | {metrics['Roam-Sim'][0]:.0f} | {metrics['Roam-Sim'][1]:.0f} |",
    f"| Roam-Dist | {metrics['Roam-Dist'][0]:.0f} | {metrics['Roam-Dist'][1]:.0f} |",
    f"| Roam      | {metrics['Roam'][0]:.0f} | {metrics['Roam'][1]:.0f} |",
]

out_path = pathlib.Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
