#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -15.80 | 1383.44 | 0.01 | 0.99 |
| MainFactorProc | -0.06 | 0.40 | -0.16 | 0.99 |
| Usage Freq. | -0.18 | 0.33 | -0.54 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.76 | 0.99 |
| StudentTrue | 15.56 | 1383.44 | 0.01 | 0.99 |

EOTABLE
# Section 2: Artifact download
curl -L -o /workspace/artifact.zip https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content
unzip -q /workspace/artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
sh run-analysis.sh > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 <<'PYTHON_EOF'
import csv
import sys
import math

def round_to_two(x):
    if x == 0:
        return 0.00
    # Round to two decimal places, but if the number is very small, use scientific notation? 
    # However, the expected table has two decimal places for all numbers, even very small ones like 0.00.
    # So we'll just round to two decimal places.
    return round(x, 2)

# Read the generated CSV file
csv_file = '/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-8-RQ1-filter.csv'
with open(csv_file, 'r') as f:
    reader = csv.reader(f)
    next(reader)  # skip header
    rows = list(reader)

# The rows are in order: (Intercept), MainFactorProc, UsageFrequency, Approvals, StudentTrue
terms = ['(Intercept)', 'MainFactorProc', 'Usage Freq.', 'Approvals', 'StudentTrue']
print("**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**")
print()
print("| Term | Estimate | Std.Error | z value | Pr(>|z|) |")
print("|---|---:|---:|---:|---:|")
for i, row in enumerate(rows):
    estimate = float(row[0])
    std_error = float(row[1])
    z_value = float(row[2])
    p_value = float(row[3])
    # Round as in the expected table
    estimate_r = round(estimate, 2)
    std_error_r = round(std_error, 2)
    z_value_r = round(z_value, 2)
    p_value_r = round(p_value, 2)
    print(f"| {terms[i]} | {estimate_r:.2f} | {std_error_r:.2f} | {z_value_r:.2f} | {p_value_r:.2f} |")
PYTHON_EOF
echo '</artisan_submit>'
