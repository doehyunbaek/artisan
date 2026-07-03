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
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert evaluation results PDF to Markdown
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results.md
# Compute averages/medians (in seconds, rounded to nearest integer, half away from zero) and emit the reproduced Table 4 into /workspace/repro.txt
python - << 'PY' > /workspace/repro.txt
import math
from statistics import mean, median

path = "/workspace/results.md"

rows = []
with open(path, "r") as f:
    for line in f:
        if not line.startswith("|"):
            continue
        parts = line.strip().split("|")
        if len(parts) < 3:
            continue
        try:
            idx = int(parts[1])
        except ValueError:
            continue
        cols = [c.strip() for c in parts[1:-1]]
        rows.append(cols)

def parse_float(val):
    try:
        return float(val)
    except Exception:
        return math.nan

def col_vals(col_idx):
    vs = [parse_float(r[col_idx]) for r in rows]
    return [v for v in vs if not math.isnan(v)]

metrics = {
    "ROAM_PRM": 9,
    "ROAM_EventSearch": 10,
    "ROAM_PathRecvExec": 11,
    "ROAM_Total": 8,
    "ReCDroid": 23,
    "Yakusu": 55,
}

stats = {}
for name, idx in metrics.items():
    vs = col_vals(idx)
    stats[name] = {
        "avg": mean(vs),
        "mdn": median(vs),
    }

def round_half_away(x: float) -> int:
    # All times are non-negative, so this simplifies
    return int(math.floor(x + 0.5))

rounded = {
    name: {
        "avg": round_half_away(vals["avg"]),
        "mdn": round_half_away(vals["mdn"]),
    }
    for name, vals in stats.items()
}

def fmt_int(name, kind, with_commas=False):
    v = rounded[name][kind]
    return f"{v:,}" if with_commas else str(v)

table = f"""**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      {fmt_int('ROAM_PRM','avg')}      |        {fmt_int('ROAM_EventSearch','avg')}        |          {fmt_int('ROAM_PathRecvExec','avg')}         |  **{fmt_int('ROAM_Total','avg')}**  |   {fmt_int('ReCDroid','avg',True)}  |  {fmt_int('Yakusu','avg',True)} |
| **Mdn.** |       {fmt_int('ROAM_PRM','mdn')}      |         {fmt_int('ROAM_EventSearch','mdn')}        |          {fmt_int('ROAM_PathRecvExec','mdn')}         |  **{fmt_int('ROAM_Total','mdn')}**  |   {fmt_int('ReCDroid','mdn',True)}  |  {fmt_int('Yakusu','mdn',True)} |
"""
print(table)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
