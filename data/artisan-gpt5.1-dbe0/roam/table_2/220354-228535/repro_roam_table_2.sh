#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**

|                 | Match Accuracy | Perfect Cases   | Zero Cases  |
| --------------- | :------------: | :-----------:   | :--------:  |
| PRM-Enumeration |       ??       |       ??      |     ??     |
| Euler           |       ??       |       ??      |     ??     |
| Roam            |       ??       |       ??      |      ?     |

EOTABLE
# Section 2: Artifact download
# Download and extract the ROAM artifact from Zenodo
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the detailed Evaluation results PDF to Markdown for easier parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results.md
# Parse the Markdown table to compute match accuracy statistics and render Table 2
python - <<'PY'
import os

results_path = "/workspace/results.md"
if not os.path.exists(results_path):
    raise SystemExit(f"Results file not found at {results_path}")

with open(results_path, "r", encoding="utf-8") as f:
    lines = [line.rstrip("\n") for line in f]

# Collect all lines that look like table rows
table_lines = [ln for ln in lines if ln.startswith("|")]
if len(table_lines) < 4:
    raise SystemExit("Unexpected table structure in results.md")

def split_row(row: str):
    cells = [c.strip() for c in row.strip().split("|")]
    if cells and cells[0] == "":
        cells = cells[1:]
    if cells and cells[-1] == "":
        cells = cells[:-1]
    return cells

# First table header row: contains method labels like ROAM, PRM-Enumeration, Euler
methods_row = split_row(table_lines[0])
# Third row (index 2) contains metric labels like Match<br>Accuracy
metrics_row = split_row(table_lines[2])

target_methods = ["ROAM", "PRM-Enumeration", "Euler"]
indices = {}

for idx, (meth, metric) in enumerate(zip(methods_row, metrics_row)):
    if meth in target_methods and metric == "Match<br>Accuracy":
        indices[meth] = idx

missing = [m for m in target_methods if m not in indices]
if missing:
    raise SystemExit(f"Could not locate Match Accuracy columns for: {missing}")

values = {m: [] for m in target_methods}

for row in table_lines[3:]:
    cells = split_row(row)
    # Only consider rows where the first cell is a numeric bug report id
    if not cells or not cells[0].isdigit():
        continue
    for meth, idx in indices.items():
        if idx >= len(cells):
            continue
        cell = cells[idx].strip()
        if not cell:
            continue
        try:
            val = float(cell)
        except ValueError:
            continue
        values[meth].append(val)

stats = {}
for meth, arr in values.items():
    if not arr:
        raise SystemExit(f"No match accuracy values collected for {meth}")
    n = len(arr)
    avg = sum(arr) / n * 100.0
    perfect = sum(1 for v in arr if v == 1.0) / n * 100.0
    zero = sum(1 for v in arr if v == 0.0) / n * 100.0
    stats[meth] = (avg, perfect, zero)

def fmt_triplet(trip):
    return tuple(f"{x:.1f}" for x in trip)

formatted = {m: fmt_triplet(trip) for m, trip in stats.items()}

rows = [
    ("PRM-Enumeration", "PRM-Enumeration"),
    ("Euler", "Euler"),
    ("ROAM", "Roam"),
]

out_path = "/workspace/repro.txt"
with open(out_path, "w", encoding="utf-8") as out:
    out.write("**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**\n\n")
    out.write("|                 | Match Accuracy | Perfect Cases   | Zero Cases  |\n")
    out.write("| --------------- | :------------: | :-----------:   | :--------:  |\n")
    for key, label in rows:
        mean, perfect, zero = formatted[key]
        out.write(f"| {label:<15} | {mean:>13} | {perfect:>13} | {zero:>10} |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
