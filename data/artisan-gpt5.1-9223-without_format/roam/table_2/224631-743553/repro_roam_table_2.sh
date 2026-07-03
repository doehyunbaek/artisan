#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**

|                 | Match Accuracy | Perfect Cases   | Zero Cases  |
| --------------- | :------------: | :-----------:   | :--------:  |
| PRM-Enumeration |       61       |       56        |     33      |
| Euler           |       72       |       56        |     14      |
| Roam            |       93       |       85        |      0      |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809

# Section 3: Reproduction commands
# Convert the Evaluation results PDF to Markdown for parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > ROAM-Artifact/ROAM-Artifact/Evaluation/results.md

# Aggregate match accuracy and case percentages, and write the reproduced table to /workspace/repro.txt
python - << "PY" > /workspace/repro.txt
path = "ROAM-Artifact/ROAM-Artifact/Evaluation/results.md"
with open(path, encoding="utf-8") as f:
    lines = [l.rstrip("\n") for l in f]

# Data rows start after the three header rows:
# 0: note, 1: column names, 2: separator, 3: label row
data_lines = lines[4:]

# Column indices for per-bug Match Accuracy (0-based in the Markdown split)
COLS = {
    "Roam": 6,
    "PRM-Enumeration": 18,
    "Euler": 20,
}

stats = {
    k: {"sum": 0.0, "n": 0, "perfect": 0, "zero": 0}
    for k in COLS
}

for line in data_lines:
    if not line.startswith("|"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if not cells or not cells[0].isdigit():
        continue  # skip non-data rows
    for tool, idx in COLS.items():
        if idx >= len(cells):
            continue
        v = cells[idx]
        if not v:
            continue
        try:
            x = float(v)
        except ValueError:
            continue
        s = stats[tool]
        s["sum"] += x
        s["n"] += 1
        if abs(x - 1.0) < 1e-9:
            s["perfect"] += 1
        if abs(x - 0.0) < 1e-9:
            s["zero"] += 1

# Compute averages and percentages as whole-number percentages
for tool, s in stats.items():
    n = s["n"]
    avg_pct = (s["sum"] / n * 100.0) if n > 0 else float("nan")
    perfect_pct = (s["perfect"] / n * 100.0) if n > 0 else float("nan")
    zero_pct = (s["zero"] / n * 100.0) if n > 0 else float("nan")
    s["avg_int"] = int(round(avg_pct))
    s["perfect_int"] = int(round(perfect_pct))
    s["zero_int"] = int(round(zero_pct))

prm = stats["PRM-Enumeration"]
euler = stats["Euler"]
roam = stats["Roam"]

print("**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**")
print()
print("|                 | Match Accuracy | Perfect Cases   | Zero Cases  |")
print("| --------------- | :------------: | :-----------:   | :--------:  |")
print(f"| PRM-Enumeration |       {prm['avg_int']}       |       {prm['perfect_int']}        |     {prm['zero_int']}      |")
print(f"| Euler           |       {euler['avg_int']}       |       {euler['perfect_int']}        |     {euler['zero_int']}      |")
print(f"| Roam            |       {roam['avg_int']}       |       {roam['perfect_int']}        |      {roam['zero_int']}      |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
