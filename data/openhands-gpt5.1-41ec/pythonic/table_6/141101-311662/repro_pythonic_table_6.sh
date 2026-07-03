#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | 16.48 | 1370.51 | 0.01 | 0.99 |
| MainFactorProc | 0.67 | 0.48 | 1.39 | 0.82 |
| Usage Freq. | -0.03 | 0.38 | -0.09 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.07 | 0.99 |
| StudentTrue | -15.75 | 1370.51 | -0.01 | 0.99 |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -d ICSE2024-funcConstructs-Artifacts ]; then
  curl -L "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content" -o ICSE2024-funcConstructs-Artifacts.zip
  unzip -q ICSE2024-funcConstructs-Artifacts.zip -d /workspace
fi
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
# Ensure required Docker image is available
docker pull mdipenta/rexp
# Run the analysis script to regenerate all tables
sh run-analysis.sh
# Extract and format Table 6 (map logistic regression) to /workspace/repro.txt
python - <<'PY'
import csv
from pathlib import Path

results_path = Path('/workspace/ICSE2024-funcConstructs-Artifacts/results/Table-6-RQ1-map.csv')
repro_path = Path('/workspace/repro.txt')

terms = [
    '(Intercept)',
    'MainFactorProc',
    'Usage Freq.',
    'Approvals',
    'StudentTrue',
]

rows = []
with results_path.open(newline='') as f:
    reader = csv.reader(f)
    header = next(reader)  # Estimate, Std. Error, z value, Pr(>|z|)
    for row in reader:
        if not row:
            continue
        rows.append([float(x) for x in row])

with repro_path.open('w', encoding='utf-8') as f:
    f.write('**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**\n\n')
    f.write('| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |\n')
    f.write('|---|---:|---:|---:|---:|\n')
    for term, (est, se, z, p) in zip(terms, rows):
        f.write(f"| {term} | {est:.2f} | {se:.2f} | {z:.2f} | {p:.2f} |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
