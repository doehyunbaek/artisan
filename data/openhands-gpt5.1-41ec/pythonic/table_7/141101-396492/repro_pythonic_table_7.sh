#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>|z|) |
|---|---:|---:|---:|---:|
| (Intercept) | -13.20 | 1696.36 | -0.01 | 0.99 |
| MainFactorProc | -0.26 | 0.47 | -0.56 | 0.99 |
| Usage Freq. | -0.83 | 0.44 | -1.87 | 0.30 |
| Approvals | 0.00 | 0.00 | -0.36 | 0.99 |
| StudentTrue | 14.38 | 1696.36 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
ARTIFACT_ZIP="/workspace/ICSE2024-funcConstructs-Artifacts.zip"
ARTIFACT_DIR="/workspace/ICSE2024-funcConstructs-Artifacts"

# Download the replication package from Zenodo
curl -L 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content' -o "${ARTIFACT_ZIP}"

# Extract the artifact contents
unzip -o "${ARTIFACT_ZIP}" -d /workspace

# Section 3: Reproduction commands (populate from reviewed steps)
cd "${ARTIFACT_DIR}" || exit 1

# Ensure the required Docker image is available
docker pull mdipenta/rexp:latest

# Run the authors' analysis script inside Docker
sh run-analysis.sh

# Extract Table 7 (reduce logistic regression) into /workspace/repro.txt
python - << 'PY'
import csv
from pathlib import Path

results_csv = Path('/workspace/ICSE2024-funcConstructs-Artifacts/results/Table-7-RQ1-reduce.csv')
rows = list(csv.reader(results_csv.open()))
header, data_rows = rows[0], rows[1:]

term_labels = [
    '(Intercept)',
    'MainFactorProc',
    'Usage Freq.',
    'Approvals',
    'StudentTrue',
]

out_path = Path('/workspace/repro.txt')
with out_path.open('w', encoding='utf-8') as f:
    f.write('**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**\n\n')
    f.write('| Term | Estimate | Std.Error | z value | Pr(>|z|) |\n')
    f.write('|---|---:|---:|---:|---:|\n')
    for label, row in zip(term_labels, data_rows):
        est, se, z, p = map(float, row)
        f.write(f'| {label} | {est:.2f} | {se:.2f} | {z:.2f} | {p:.2f} |\n')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
