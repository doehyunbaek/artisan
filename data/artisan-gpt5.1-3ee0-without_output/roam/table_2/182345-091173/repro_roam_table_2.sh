#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**

|                 | Match Accuracy | Perfect Cases | Zero Cases |
| --------------- | :------------: | :-----------: | :--------: |
| PRM-Enumeration |      61.34     |     55.56     |   33.33    |
| Euler           |      71.52     |     55.56     |   13.89    |
| Roam            |      93.39     |     84.72     |    0.00    |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809

# Section 3: Reproduction commands (populate from reviewed steps)
# Compute the same statistics from Evaluation/results.pdf and emit a markdown table to /workspace/repro.txt
python - << 'PY' > /workspace/repro.txt
import math
import os
from pathlib import Path

root = Path("ROAM-Artifact/ROAM-Artifact/Evaluation")
pdf_path = root / "results.pdf"
md_path = root / "results_table.md"

# Convert PDF to markdown table if not already present
if not md_path.exists():
    os.system(f"uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; "
              f"sys.stdout.write(p.to_markdown(sys.argv[1]))' '{pdf_path}' > '{md_path}'")

roam_vals = []
prm_vals = []
euler_vals = []

with md_path.open("r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("|"):
            continue
        parts = line.split("|")
        if len(parts) < 5:
            continue
        cells = parts[1:-1]  # drop leading/trailing empties
        if not cells or not cells[0].strip().isdigit():
            continue

        def get_float(idx):
            if idx >= len(cells):
                return None
            s = cells[idx].strip()
            if not s:
                return None
            try:
                return float(s)
            except ValueError:
                return None

        # Column indices from header inspection
        r = get_float(6)   # ROAM Match Accuracy
        p = get_float(18)  # PRM-Enumeration Match Accuracy
        e = get_float(20)  # Euler Match Accuracy

        if r is not None:
            roam_vals.append(r)
        if p is not None:
            prm_vals.append(p)
        if e is not None:
            euler_vals.append(e)

def summarize(vals):
    n = len(vals)
    mean = sum(vals) / n
    perfect = sum(1 for v in vals if abs(v - 1.0) < 1e-9) / n
    zero = sum(1 for v in vals if abs(v) < 1e-9) / n
    # Convert to percentages with two decimal places
    return (round(mean * 100, 2),
            round(perfect * 100, 2),
            round(zero * 100, 2))

roam_avg, roam_perfect, roam_zero = summarize(roam_vals)
prm_avg, prm_perfect, prm_zero = summarize(prm_vals)
eul_avg, eul_perfect, eul_zero = summarize(euler_vals)

print("**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**\n")
print("|                 | Match Accuracy | Perfect Cases | Zero Cases |")
print("| --------------- | :------------: | :-----------: | :--------: |")
print(f"| PRM-Enumeration |   {prm_avg:.2f}   |   {prm_perfect:.2f}   |  {prm_zero:.2f}  |")
print(f"| Euler           |   {eul_avg:.2f}   |   {eul_perfect:.2f}   |  {eul_zero:.2f}  |")
print(f"| Roam            |   {roam_avg:.2f}   |   {roam_perfect:.2f}   |  {roam_zero:.2f}  |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
