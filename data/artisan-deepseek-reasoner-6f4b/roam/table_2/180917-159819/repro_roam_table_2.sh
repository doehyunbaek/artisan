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
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
cd ROAM-Artifact/ROAM-Artifact
# Extract Table 2 results from the evaluation results PDF
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' Evaluation/results.pdf > /workspace/table.md
# Parse the table and compute the required statistics for Table 2
python3 << 'PYEOF'
import sys
with open('/workspace/table.md', 'r') as f:
    lines = [line.rstrip() for line in f]
# Find header rows and separator
header1_line = None
separator_line = None
header2_line = None
for i, line in enumerate(lines):
    if line.startswith('|'):
        if all(c in '|- ' for c in line):
            if header1_line is not None and separator_line is None:
                separator_line = i
        else:
            if header1_line is None:
                header1_line = i
            elif separator_line is not None and header2_line is None:
                header2_line = i
                break
header1 = lines[header1_line].split('|')[1:-1]
header2 = lines[header2_line].split('|')[1:-1]
header1 = [h.strip() for h in header1]
header2 = [h.strip() for h in header2]
methods = ['ROAM', 'PRM-Enumeration', 'Euler']
method_positions = {}
for idx, h in enumerate(header1):
    if h in methods:
        method_positions[h] = idx
method_cols = {}
for method, start_idx in method_positions.items():
    next_positions = [pos for pos in method_positions.values() if pos > start_idx]
    end_idx = min(next_positions) if next_positions else len(header1)
    found = None
    for idx in range(start_idx, end_idx):
        if 'Match' in header2[idx]:
            found = idx
            break
    if found is not None:
        method_cols[method] = found
data_start = header2_line + 1
data_rows = []
for line in lines[data_start:]:
    if not line.startswith('|'):
        break
    row = line.split('|')[1:-1]
    row = [cell.strip() for cell in row]
    if len(row) >= len(header1):
        data_rows.append(row)
values = {method: [] for method in methods}
for row in data_rows:
    for method in methods:
        col = method_cols.get(method)
        if col is not None and col < len(row):
            val_str = row[col]
            try:
                val = float(val_str)
                values[method].append(val)
            except ValueError:
                values[method].append(None)
def compute_stats(vals):
    valid = [v for v in vals if v is not None]
    if not valid:
        return 0.0, 0, 0
    avg = sum(valid) / len(valid)
    perfect = sum(1 for v in valid if v == 1.0)
    zero = sum(1 for v in valid if v == 0.0)
    return avg, perfect, zero
results = {}
for method in methods:
    avg, perfect, zero = compute_stats(values[method])
    results[method] = (avg, perfect, zero)
with open('/workspace/repro.txt', 'w') as f:
    for method in ['PRM-Enumeration', 'Euler', 'ROAM']:
        avg, perfect, zero = results[method]
        f.write(f"{method} Match Accuracy: {avg*100:.2f}%\n")
        f.write(f"{method} Perfect Cases: {perfect}\n")
        f.write(f"{method} Zero Cases: {zero}\n")
PYEOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
