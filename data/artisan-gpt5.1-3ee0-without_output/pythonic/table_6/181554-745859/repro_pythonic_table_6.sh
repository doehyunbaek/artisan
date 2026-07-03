#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | ??.?? | ????.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | -??.?? | ????.?? | -?.?? | ?.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
./run-analysis.sh

# Build the reproduction table for Table 6 from the generated CSV
python - << 'PY'
import csv
from pathlib import Path

csv_path = Path("results") / "Table-6-RQ1-map.csv"
with csv_path.open() as f:
    reader = csv.DictReader(f)
    rows = list(reader)

terms = ["(Intercept)", "MainFactorProc", "Usage Freq.", "Approvals", "StudentTrue"]

def fmt(x):
    return f"{float(x):.3f}"

lines = []
lines.append("**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**\n")
lines.append("")
lines.append("| Term | Estimate | Std.Error | z value | Pr(>|z|) |")
lines.append("|---|---:|---:|---:|---:|")

for term, row in zip(terms, rows):
    est = fmt(row["Estimate"])
    se = fmt(row["Std. Error"])
    z = fmt(row["z value"])
    p = fmt(row["Pr(>|z|)"])
    lines.append(f"| {term} | {est} | {se} | {z} | {p} |")

out_path = Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
