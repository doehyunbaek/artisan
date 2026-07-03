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

# Section 3: Reproduction commands
# Convert Evaluation/results.pdf to markdown so we can parse the per-subject running times.
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' \
  ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /tmp/roam_results.md

# Parse the markdown table to compute averages and medians for the required columns
python - << 'PY' > /workspace/repro.txt
import pathlib, statistics

path = pathlib.Path("/tmp/roam_results.md")
with path.open() as f:
    lines = [ln.rstrip("\n") for ln in f]

data_rows = []
for ln in lines:
    if not ln.startswith("|"):
        continue
    parts = [p.strip() for p in ln.split("|")]
    # Data rows have an index (1..72) in column position 1
    if len(parts) < 57:
        continue
    if not parts[1].isdigit():
        continue
    idx = int(parts[1])
    if 1 <= idx <= 72:
        data_rows.append(parts)

def col_float(parts, idx):
    v = parts[idx]
    if v == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None

# Column indices as inferred from the header:
#  - Roam total running time                -> col 9
#  - Roam PRM construction time             -> col 10
#  - Roam event search time                 -> col 11
#  - Roam path recovery & execution time    -> col 12
#  - ReCDroid running time                  -> col 24
#  - Yakusu running time                    -> col 56
cols = {
    "roam_total": 9,
    "roam_prm": 10,
    "roam_search": 11,
    "roam_path": 12,
    "recdroid": 24,
    "yakusu": 56,
}

vals = {k: [] for k in cols}
for parts in data_rows:
    for key, idx in cols.items():
        v = col_float(parts, idx)
        if v is not None:
            vals[key].append(v)

def avg(arr):
    return sum(arr) / len(arr)

def med(arr):
    return statistics.median(arr)

avg_prm      = avg(vals["roam_prm"])
avg_search   = avg(vals["roam_search"])
avg_path     = avg(vals["roam_path"])
avg_total    = avg(vals["roam_total"])
avg_recdroid = avg(vals["recdroid"])
avg_yakusu   = avg(vals["yakusu"])

med_prm      = med(vals["roam_prm"])
med_search   = med(vals["roam_search"])
med_path     = med(vals["roam_path"])
med_total    = med(vals["roam_total"])
med_recdroid = med(vals["recdroid"])
med_yakusu   = med(vals["yakusu"])

print("**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**\n")
print("|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |")
print("| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |")
print("|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |")
print(f"| **Avg.** |  {avg_prm:.3f}  |    {avg_search:.3f}    |      {avg_path:.3f}       | **{avg_total:.3f}** | {avg_recdroid:.3f} | {avg_yakusu:.3f} |")
print(f"| **Mdn.** |  {med_prm:.3f}  |    {med_search:.3f}    |      {med_path:.3f}       | **{med_total:.3f}** | {med_recdroid:.3f} | {med_yakusu:.3f} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
