#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ROAM-Artifact.zip https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content
unzip ROAM-Artifact.zip -d ROAM-Artifact
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > ROAM-Artifact/ROAM-Artifact/Evaluation/results.md

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


echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
