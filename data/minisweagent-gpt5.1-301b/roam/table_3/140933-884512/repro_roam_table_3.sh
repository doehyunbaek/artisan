#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      29     |             27            |            30            |
| Yakusu   |      8      |             15            |             4            |
| Roam     |      94     |             96            |            93            |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f ROAM-Artifact.zip ]; then
  curl -L -o ROAM-Artifact.zip https://zenodo.org/records/11068809/files/ROAM-Artifact.zip
fi
unzip -o ROAM-Artifact.zip 'ROAM-Artifact/*' -d /workspace >/dev/null

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ROAM-Artifact/Evaluation
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' results.pdf > results.md

python - << 'PY'
import pathlib, sys

root = pathlib.Path("/workspace/ROAM-Artifact/Evaluation")
text = (root / "results.md").read_text()
lines = [l for l in text.splitlines() if l.strip()]

# Locate header rows
h1_idx = next(i for i, l in enumerate(lines) if l.startswith("|Col1|Col2|Col3"))
h1 = lines[h1_idx].strip()
h2 = lines[h1_idx + 2].strip()

def split_row(row: str):
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|"):
        row = row[:-1]
    return [c.strip() for c in row.split("|")]

h1_cols = split_row(h1)
h2_cols = split_row(h2)
ncols = len(h1_cols)
if ncols != len(h2_cols):
    sys.exit(f"Header length mismatch: {ncols} vs {len(h2_cols)}")

# Column indices derived from the header structure
IDX_MISSING = 5          # "# Missing Steps"
IDX_ROAM_RR = 7          # ROAM reproduction result
IDX_RECDROID_RR = 22     # ReCDroid reproduction result
IDX_YAKUSU_RR = 54       # Yakusu reproduction result

# Collect data rows
data_rows = []
for line in lines[h1_idx + 3:]:
    if not line.startswith("|"):
        continue
    cols = split_row(line)
    try:
        int(cols[0])
    except (ValueError, IndexError):
        continue
    if len(cols) < ncols:
        cols += [""] * (ncols - len(cols))
    data_rows.append(cols)

if len(data_rows) != 72:
    sys.exit(f"Expected 72 reports, found {len(data_rows)}")

def has_missing(val: str) -> bool:
    s = val.strip()
    if not s:
        return False
    try:
        return int(s) > 0
    except ValueError:
        return False

groups = {
    "all": lambda row: True,
    "no_missing": lambda row: not has_missing(row[IDX_MISSING]),
    "with_missing": lambda row: has_missing(row[IDX_MISSING]),
}

tool_indices = {
    "ReCDroid": IDX_RECDROID_RR,
    "Yakusu":   IDX_YAKUSU_RR,
    "Roam":     IDX_ROAM_RR,
}

stats = {tool: {g: {"succ": 0, "tot": 0} for g in groups} for tool in tool_indices}

for row in data_rows:
    for gname, gpred in groups.items():
        if not gpred(row):
            continue
        for tool, idx in tool_indices.items():
            val = row[idx].strip().lower()
            stats[tool][gname]["tot"] += 1
            if val == "success":
                stats[tool][gname]["succ"] += 1

def pct(succ, tot):
    return 0 if tot == 0 else int(round(100.0 * succ / tot))

computed = {
    tool: {g: pct(v["succ"], v["tot"]) for g, v in group.items()}
    for tool, group in stats.items()
}

expected = {
    "ReCDroid": {"all": 29, "no_missing": 27, "with_missing": 30},
    "Yakusu":   {"all": 8,  "no_missing": 15, "with_missing": 4},
    "Roam":     {"all": 94, "no_missing": 96, "with_missing": 93},
}

for tool in expected:
    for g in expected[tool]:
        if computed[tool][g] != expected[tool][g]:
            sys.exit(
                f"Mismatch for {tool} {g}: expected {expected[tool][g]}, "
                f"got {computed[tool][g]}"
            )

table_text = """**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      29     |             27            |            30            |
| Yakusu   |      8      |             15            |             4            |
| Roam     |      94     |             96            |            93            |
"""

path = pathlib.Path("/workspace/repro.txt")
path.write_text(table_text)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
