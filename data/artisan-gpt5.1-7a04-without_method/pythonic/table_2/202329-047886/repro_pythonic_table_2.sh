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
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh
# Extract Table 2 data and render as markdown into /workspace/repro.txt
python - <<'EOPY'
import csv, pathlib, sys

root = pathlib.Path("/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts")
table_path = root / "results" / "Table-2-descriptive.csv"
rows = []
with table_path.open(newline='') as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

# Map construct codes to labels used in the paper table
label_map = {"lambda": "Lambda", "comp": "Compr.", "mrf": "MRF"}
# Order to match the paper
order = ["lambda", "comp", "mrf"]

lines = []
lines.append("**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**\n")
lines.append("")
lines.append("| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |")
lines.append("| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |")

# Build a lookup by construct
by_construct = {r["Construct"]: r for r in rows}

for key in order:
    r = by_construct[key]
    label = label_map[key]
    f_true = int(float(r["Ftrue"]))
    f_false = int(float(r["Ffalse"]))
    p_true = int(float(r["Ptrue"]))
    p_false = int(float(r["Pfalse"]))
    f_perc = round(float(r["Fperc"]), 2)
    p_perc = round(float(r["Pperc"]), 2)
    # Format with two decimals
    lines.append(
        f"| {label:<7} | {f_true:21d} | {f_false:21d} | {f_perc:23.2f} | {p_true:21d} | {p_false:21d} | {p_perc:23.2f} |"
    )

out_path = pathlib.Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines), encoding="utf-8")
EOPY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
