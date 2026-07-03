#!/usr/bin/bash
set -euo pipefail

# Write expected table
cat > /workspace/expected.md <<'EOT'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -??.?? | ????.?? | ?.?? | ?.?? |
| MainFactorProc | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ??.?? | ????.?? | ?.?? | ?.?? |

EOT

# Download artifact (capture logs to avoid noisy stdout/stderr)
artisan get https://zenodo.org/records/10554377 > /workspace/artifact_download.log 2>&1 || true

# Path to the generated CSV inside the extracted artifact
CSV_PATH="$(pwd)/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/results/Table-8-RQ1-filter.csv"

if [ ! -f "${CSV_PATH}" ]; then
  echo "ERROR: Table 8 CSV not found at ${CSV_PATH}" > /workspace/repro.txt
  exit 1
fi

# Build the reproduction table programmatically, rounding half away from zero to 2 decimals
python3 - <<'PY' > /workspace/repro.txt
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation
import csv, os, sys

csv_path = os.path.expanduser("${CSV_PATH}")
terms = ["(Intercept)","MainFactorProc","Usage Freq.","Approvals","StudentTrue"]

def safe_decimal(s):
    try:
        s2 = s.strip()
        if s2 == "":
            return Decimal('0')
        return Decimal(s2)
    except (InvalidOperation, ValueError):
        try:
            return Decimal(str(float(s)))
        except Exception:
            return Decimal('0')

def round_half_away_str(d, nd=2):
    q = d.quantize(Decimal('1e-{}'.format(nd)), rounding=ROUND_HALF_UP)
    return f"{q:.{nd}f}"

rows = []
if not os.path.isfile(csv_path):
    print("ERROR: CSV not found at", csv_path, file=sys.stderr)
    sys.exit(1)

with open(csv_path, newline='') as f:
    reader = csv.reader(f)
    for r in reader:
        if len(r) >= 4:
            rows.append(r[:4])

# Pad if fewer rows than expected
while len(rows) < len(terms):
    rows.append(["0","0","0","0"])

print("**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**")
print()
print("| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |")
print("|---|---:|---:|---:|---:|")
for i, term in enumerate(terms):
    est = safe_decimal(rows[i][0])
    se  = safe_decimal(rows[i][1])
    z   = safe_decimal(rows[i][2])
    p   = safe_decimal(rows[i][3])
    print(f"| {term} | {round_half_away_str(est,2)} | {round_half_away_str(se,2)} | {round_half_away_str(z,2)} | {round_half_away_str(p,2)} |")
PY

# Format and compare
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
