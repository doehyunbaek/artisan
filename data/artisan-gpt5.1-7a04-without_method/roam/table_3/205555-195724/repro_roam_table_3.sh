#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      ??     |             ??            |            ??            |
| Yakusu   |      ?      |             ??            |             ?            |
| Roam     |      ??     |             ??            |            ??            |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ROAM-Artifact/ROAM-Artifact/Evaluation
uvx --from pymupdf4llm python -c 'import sys,pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' results.pdf > results_converted.md
python - << 'PY' > /workspace/repro.txt
import os

path = "/workspace/ROAM-Artifact/ROAM-Artifact/Evaluation/results_converted.md"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

table_lines = [l.rstrip("\n") for l in lines if l.lstrip().startswith("|")]
if len(table_lines) < 4:
    raise SystemExit("Table appears incomplete in results_converted.md")

h1 = table_lines[0]  # group header row (Col1, Col2, ..., ROAM, ..., ReCDroid, ..., Yakusu)
h2 = table_lines[2]  # field header row (# Missing Steps, Reproduction<br>Result, etc.)
data_lines = table_lines[3:]

def split_row(row):
    parts = row.strip().split("|")
    return [p.strip() for p in parts[1:-1]]  # drop outer empties from leading/trailing pipes

h1_cells = split_row(h1)
h2_cells = split_row(h2)

if len(h1_cells) != len(h2_cells):
    raise SystemExit(f"Header length mismatch: {len(h1_cells)} vs {len(h2_cells)}")

# Locate "# Missing Steps" column
try:
    idx_missing = h2_cells.index("# <br>Missing<br>Steps")
except ValueError:
    raise SystemExit("Could not find '# <br>Missing<br>Steps' column")

tools = ["ROAM", "ReCDroid", "Yakusu"]
tool_rr_idx = {}

# For each tool, find its first "Reproduction<br>Result" column within its header group
for tool in tools:
    try:
        start = h1_cells.index(tool)
    except ValueError:
        raise SystemExit(f"Could not find tool group start for {tool} in header row")
    idx = None
    for j in range(start, len(h2_cells)):
        if h2_cells[j] == "Reproduction<br>Result":
            idx = j
            break
        if h1_cells[j] in tools and j != start:
            break
    if idx is None:
        raise SystemExit(f"Could not find Reproduction Result column for {tool}")
    tool_rr_idx[tool] = idx

# stats: {tool: [succ_all, total_all, succ_nomiss, total_nomiss, succ_miss, total_miss]}
stats = {t: [0, 0, 0, 0, 0, 0] for t in tools}

for line in data_lines:
    if not line.strip() or line.strip().startswith("|---"):
        continue
    cells = split_row(line)
    if len(cells) != len(h1_cells):
        continue

    ms_raw = cells[idx_missing].strip()
    if not ms_raw:
        continue
    try:
        missing_steps = int(float(ms_raw))
    except ValueError:
        continue

    no_missing = (missing_steps == 0)

    for tool in tools:
        idx_rr = tool_rr_idx[tool]
        rr = cells[idx_rr].strip().lower()
        if rr in ("", "na"):
            continue

        sa, ta, sn, tn, sm, tm = stats[tool]

        ta += 1
        if rr == "success":
            sa += 1

        if no_missing:
            tn += 1
            if rr == "success":
                sn += 1
        else:
            tm += 1
            if rr == "success":
                sm += 1

        stats[tool] = [sa, ta, sn, tn, sm, tm]

def pct(succ, tot):
    return 0.0 if tot == 0 else 100.0 * succ / tot

# Convert to rounded integer percentages for the table
percents = {}
for tool in tools:
    sa, ta, sn, tn, sm, tm = stats[tool]
    percents[tool] = (
        int(round(pct(sa, ta))),
        int(round(pct(sn, tn))),
        int(round(pct(sm, tm))),
    )

recd_all, recd_nomiss, recd_miss = percents["ReCDroid"]
yaku_all, yaku_nomiss, yaku_miss = percents["Yakusu"]
roam_all, roam_nomiss, roam_miss = percents["ROAM"]

print("**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**\n")
print("|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |")
print("| -------- | :---------: | :-----------------------: | :----------------------: |")
print(f"| ReCDroid | {recd_all} | {recd_nomiss} | {recd_miss} |")
print(f"| Yakusu   | {yaku_all} | {yaku_nomiss} | {yaku_miss} |")
print(f"| Roam     | {roam_all} | {roam_nomiss} | {roam_miss} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
