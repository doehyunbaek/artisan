#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      29     |             27            |            30            |
| Yakusu   |       8     |             15            |             4            |
| Roam     |      94     |             96            |            93            |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results.md
python - << 'PY' > /workspace/repro.txt
from pathlib import Path

results_path = Path("/workspace/results.md")
lines = results_path.read_text(encoding="utf-8").splitlines()

header1 = None
header2 = None
h1_idx = None

# Locate the two header rows
for i, line in enumerate(lines):
    if line.startswith("|Col1|Col2|Col3|Col4|Col5|Col6|ROAM|"):
        header1 = line.split("|")
        h1_idx = i
        break

if header1 is None:
    raise SystemExit("Could not find primary header row with tool names")

header2 = lines[h1_idx + 2].split("|")

tools = ["ROAM", "ReCDroid", "Yakusu"]

# Map column indices to tools using header1
tool_for_col = [None] * len(header1)
current_tool = None
for idx, cell in enumerate(header1):
    name = cell.strip()
    if name in tools:
        current_tool = name
    if current_tool in tools:
        tool_for_col[idx] = current_tool

# Find "# Missing Steps" column
missing_idx = None
for idx, cell in enumerate(header2):
    if "Missing<br>Steps" in cell:
        missing_idx = idx
        break
if missing_idx is None:
    raise SystemExit("Missing-steps column not found")

# Find reproduction-result column index for each tool
repro_col = {}
for idx, cell in enumerate(header2):
    if "Reproduction<br>Result" in cell:
        t = tool_for_col[idx]
        if t in tools and t not in repro_col:
            repro_col[t] = idx

if set(repro_col.keys()) != set(tools):
    raise SystemExit(f"Incomplete reproduction-result column mapping: {repro_col}")

stats = {
    t: {
        "all": {"succ": 0, "total": 0},
        "no_missing": {"succ": 0, "total": 0},
        "missing": {"succ": 0, "total": 0},
    }
    for t in tools
}

# Parse data rows
for line in lines[h1_idx + 3:]:
    if not line.startswith("|"):
        continue
    parts = line.split("|")
    if len(parts) <= 2:
        continue
    row_id = parts[1].strip()
    if not row_id.isdigit():
        continue

    # Determine missing-steps count
    ms_cell = parts[missing_idx].strip()
    if not ms_cell:
        missing_steps = 0
    else:
        try:
            missing_steps = int(ms_cell)
        except ValueError:
            continue

    subset = "no_missing" if missing_steps == 0 else "missing"

    for t in tools:
        col = repro_col[t]
        val = parts[col].strip().lower()
        stats[t]["all"]["total"] += 1
        stats[t][subset]["total"] += 1
        if val == "success":
            stats[t]["all"]["succ"] += 1
            stats[t][subset]["succ"] += 1

def pct_int(succ, total):
    return int(round(100.0 * succ / total)) if total else 0

# Compute integer percentages
summary = {}
for t in tools:
    s = stats[t]
    summary[t] = {
        "all": pct_int(s["all"]["succ"], s["all"]["total"]),
        "no_missing": pct_int(s["no_missing"]["succ"], s["no_missing"]["total"]),
        "missing": pct_int(s["missing"]["succ"], s["missing"]["total"]),
    }

# Map internal tool IDs to display names/order
rows = [
    ("ReCDroid", summary["ReCDroid"]["all"], summary["ReCDroid"]["no_missing"], summary["ReCDroid"]["missing"]),
    ("Yakusu",   summary["Yakusu"]["all"],   summary["Yakusu"]["no_missing"],   summary["Yakusu"]["missing"]),
    ("Roam",     summary["ROAM"]["all"],     summary["ROAM"]["no_missing"],     summary["ROAM"]["missing"]),
]

print("**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**")
print()
print("|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |")
print("| -------- | :---------: | :-----------------------: | :----------------------: |")
for name, all_p, no_miss_p, miss_p in rows:
    print(f"| {name:<8} | {all_p:^11} | {no_miss_p:^23} | {miss_p:^22} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
