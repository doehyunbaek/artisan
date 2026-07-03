#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                   53.33 |                    115 |                     95 |                   54.76 |
| Compr.    |                     99 |                    111 |                   47.14 |                    114 |                     96 |                   54.29 |
| MRF       |                     80 |                    130 |                   38.10 |                     85 |                    125 |                   40.48 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts && sh run-analysis.sh
python - << 'PY' > /workspace/repro.txt
import csv
from pathlib import Path

in_path = Path("/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/results/Table-2-descriptive.csv")
mapping = {"lambda": "Lambda", "comp": "Compr.", "mrf": "MRF"}
rows = []
with in_path.open() as f:
    reader = csv.DictReader(f)
    for r in reader:
        key = r["Construct"]
        rows.append({
            "Construct": mapping.get(key, key),
            "Ftrue": int(float(r["Ftrue"])),
            "Ffalse": int(float(r["Ffalse"])),
            "Fperc": round(float(r["Fperc"]), 2),
            "Ptrue": int(float(r["Ptrue"])),
            "Pfalse": int(float(r["Pfalse"])),
            "Pperc": round(float(r["Pperc"]), 2),
        })

print("**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**\n")
print("| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |")
print("| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |")
for r in rows:
    print(f"| {r['Construct']:<8} | {r['Ftrue']:>21} | {r['Ffalse']:>21} | {r['Fperc']:>23.2f} | {r['Ptrue']:>21} | {r['Pfalse']:>21} | {r['Pperc']:>23.2f} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
