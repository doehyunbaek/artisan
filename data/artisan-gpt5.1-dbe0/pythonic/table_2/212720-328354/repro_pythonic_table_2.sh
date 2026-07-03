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
python - << 'PY'
import csv
from collections import defaultdict, OrderedDict

csv_path = "/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1.csv"

stats = defaultdict(lambda: {"Ftrue": 0, "Ffalse": 0, "Ptrue": 0, "Pfalse": 0})

with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        section = row["Section"]
        outcome = row["Outcome"]
        main = row["MainFactor"]
        if main not in ("f", "p"):
            continue
        is_true = (outcome == "TRUE")
        if main == "f":
            key_true, key_false = "Ftrue", "Ffalse"
        else:
            key_true, key_false = "Ptrue", "Pfalse"
        stats[section][key_true if is_true else key_false] += 1

order = ["lambda", "comp", "mrf"]
labels = {"lambda": "Lambda", "comp": "Compr.", "mrf": "MRF"}
ordered = OrderedDict((s, stats[s]) for s in order)

for sec, vals in ordered.items():
    Ft, Ff = vals["Ftrue"], vals["Ffalse"]
    Pt, Pf = vals["Ptrue"], vals["Pfalse"]
    vals["Fperc"] = 100.0 * Ft / (Ft + Ff) if (Ft + Ff) > 0 else 0.0
    vals["Pperc"] = 100.0 * Pt / (Pt + Pf) if (Pt + Pf) > 0 else 0.0

out_path = "/workspace/repro.txt"
with open(out_path, "w") as out:
    out.write("**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**\n\n")
    out.write("| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |\n")
    out.write("| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |\n")
    for sec in order:
        v = ordered[sec]
        out.write(f"| {labels[sec]} | {v['Ftrue']} | {v['Ffalse']} | {v['Fperc']:.2f} | {v['Ptrue']} | {v['Pfalse']} | {v['Pperc']:.2f} |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
