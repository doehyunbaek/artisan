#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                    53.33 |                    115 |                     95 |                    54.76 |
| Compr.    |                     99 |                    111 |                    47.14 |                    114 |                     96 |                    54.29 |
| MRF       |                     80 |                    130 |                    38.10 |                     85 |                    125 |                    40.48 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
# Compute Table 2 directly from RQ1.csv and write Markdown table to /workspace/repro.txt
python - <<'PY'
import csv
from pathlib import Path

base = Path("/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts")
rq1_path = base / "working-results" / "RQ1-RQ2-files-for-statistical-analysis" / "RQ1.csv"

stats = {
    "lambda": {"Ftrue": 0, "Ffalse": 0, "Ptrue": 0, "Pfalse": 0},
    "comp":   {"Ftrue": 0, "Ffalse": 0, "Ptrue": 0, "Pfalse": 0},
    "mrf":    {"Ftrue": 0, "Ffalse": 0, "Ptrue": 0, "Pfalse": 0},
}

with rq1_path.open(newline='', encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        section = row["Section"]
        if section not in stats:
            continue
        main_factor = row["MainFactor"]  # "f" or "p"
        outcome = row["Outcome"]        # "TRUE" or "FALSE"
        key_prefix = "F" if main_factor == "f" else "P"
        if outcome == "TRUE":
            stats[section][f"{key_prefix}true"] += 1
        else:
            stats[section][f"{key_prefix}false"] += 1

def perc(true, false):
    total = true + false
    return 100.0 * true / total if total > 0 else 0.0

order = [("lambda", "Lambda"), ("comp", "Compr."), ("mrf", "MRF")]

lines = []
lines.append("**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**")
lines.append("")
lines.append("| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |")
lines.append("| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |")

for key, label in order:
    s = stats[key]
    Ftrue, Ffalse = s["Ftrue"], s["Ffalse"]
    Ptrue, Pfalse = s["Ptrue"], s["Pfalse"]
    Fperc = perc(Ftrue, Ffalse)
    Pperc = perc(Ptrue, Pfalse)
    lines.append(
        f"| {label:<8} | {Ftrue:21d} | {Ffalse:21d} | {Fperc:23.2f} | "
        f"{Ptrue:21d} | {Pfalse:21d} | {Pperc:23.2f} |"
    )

Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
