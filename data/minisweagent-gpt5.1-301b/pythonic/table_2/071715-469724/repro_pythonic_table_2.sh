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
ARTIFACT_ZIP="/workspace/ICSE2024-funcConstructs-Artifacts.zip"
ARTIFACT_DIR="/workspace/artifact"
if [ ! -f "$ARTIFACT_ZIP" ]; then
  curl -L 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content' -o "$ARTIFACT_ZIP"
fi
mkdir -p "$ARTIFACT_DIR"
unzip -o "$ARTIFACT_ZIP" -d "$ARTIFACT_DIR" >/dev/null
cd "$ARTIFACT_DIR"/ICSE2024-funcConstructs-Artifacts || exit 1

# Section 3: Reproduction commands (populate from reviewed steps)
docker pull mdipenta/rexp:latest >/dev/null
sh run-analysis.sh
python - <<'PY'
import csv
from pathlib import Path

results_csv = Path("/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-2-descriptive.csv")
rows = list(csv.DictReader(results_csv.open()))
order = {"lambda": 0, "comp": 1, "mrf": 2}
label_map = {"lambda": "Lambda", "comp": "Compr.", "mrf": "MRF"}

rows.sort(key=lambda r: order.get(r["Construct"], 99))

lines = []
lines.append("**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**")
lines.append("")
lines.append("| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |")
lines.append("| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |")

for r in rows:
    name = label_map[r["Construct"]]
    Ftrue = int(float(r["Ftrue"]))
    Ffalse = int(float(r["Ffalse"]))
    Fperc = float(r["Fperc"])
    Ptrue = int(float(r["Ptrue"]))
    Pfalse = int(float(r["Pfalse"]))
    Pperc = float(r["Pperc"])
    lines.append(
        f"| {name:<8} | {Ftrue:>20} | {Ffalse:>20} | {Fperc:>23.2f} | {Ptrue:>20} | {Pfalse:>20} | {Pperc:>23.2f} |"
    )

Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
