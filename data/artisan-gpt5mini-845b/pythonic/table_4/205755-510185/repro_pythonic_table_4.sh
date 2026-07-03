#!/usr/bin/env bash
set -euo pipefail

# Write expected template
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Compl. | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc:Compl. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
EOTABLE

# Download artifact
artisan get https://zenodo.org/records/10554377

ABS_PATH="$(pwd)/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts"
RESULTS_DIR="${ABS_PATH}/results"
TXT_FILE="${RESULTS_DIR}/Table-4-RQ1-comp.txt"
COEFF_CSV="${RESULTS_DIR}/Table-4-RQ1-comp-coeff.txt"

# Ensure fresh container
docker rm -f rexp_repro_container 2>/dev/null || true
docker pull mdipenta/rexp:latest
docker run -d --init --entrypoint bash -v "${ABS_PATH}":/data --name rexp_repro_container mdipenta/rexp:latest -c 'sleep infinity'
docker exec rexp_repro_container /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
docker rm -f rexp_repro_container || true

# Check files
if [ ! -f "${TXT_FILE}" ] || [ ! -f "${COEFF_CSV}" ]; then
  echo "Expected result files missing under ${RESULTS_DIR}" >&2
  ls -la "${RESULTS_DIR}" || true
  exit 1
fi

# Parse AIC/BIC/logLik/deviance/df.resid robustly from TXT_FILE
header_line=$(awk '/AIC/ && /df.resid/ {getline; gsub(/^[ \t]+|[ \t]+$/,""); print; exit}' "${TXT_FILE}")
# header_line expected like: "   534.7    566.3   -259.3    518.7      378"
read -r AIC BIC LOGLik DEVIANCE DFRESID <<< "$(echo "${header_line}" | awk '{print $1, $2, $3, $4, $5}')"

# Read coefficients CSV skipping empty lines; expect header then rows
# Use awk to extract numeric columns and format with sprintf to required decimals
# We'll collect 7 rows (Intercept, MainFactorp, Complexity, UsageFrequency, Approvals, StudentTRUE, MainFactorp:Complexity)
ORs=(); ESTs=(); SEs=(); Zs=(); Ps=()
awk -F, 'NF>1 {gsub(/^[ \t]+|[ \t]+$/,"",$0); print}' "${COEFF_CSV}" > /tmp/coeff_lines.csv
count=$(wc -l < /tmp/coeff_lines.csv)
if [ "$count" -lt 8 ]; then
  echo "Coefficient CSV has unexpected format or too few lines ($count)" >&2
  cat /tmp/coeff_lines.csv >&2
  exit 1
fi

# Read rows 2..8 (skip header)
for i in $(seq 2 8); do
  line=$(awk -F, "NR==${i}{print \$1\",\"\$2\",\"\$3\",\"\$4\",\"\$5}" /tmp/coeff_lines.csv)
  # split fields robustly with awk again
  or=$(echo "${line}" | awk -F, '{print $1}')
  est=$(echo "${line}" | awk -F, '{print $2}')
  se=$(echo "${line}" | awk -F, '{print $3}')
  z=$(echo "${line}" | awk -F, '{print $4}')
  p=$(echo "${line}" | awk -F, '{print $5}')
  ORs+=("$(awk -v v="${or}" 'BEGIN{printf "%.2f", v}')")
  ESTs+=("$(awk -v v="${est}" 'BEGIN{printf "%.2f", v}')")
  SEs+=("$(awk -v v="${se}" 'BEGIN{printf "%.2f", v}')")
  Zs+=("$(awk -v v="${z}" 'BEGIN{printf "%.2f", v}')")
  Ps+=("$(awk -v v="${p}" 'BEGIN{printf "%.2f", v}')")
done

# Write repro.txt using derived values
cat > /workspace/repro.txt <<EOT
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ${AIC}  |
| **BIC**          | ${BIC}  |
| **logLik**       | ${LOGLik} |
| **deviance**     | ${DEVIANCE}  |
| **df.residuals** | ${DFRESID}    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ${ORs[0]} | ${ESTs[0]} | ${SEs[0]} | ${Zs[0]} | ${Ps[0]} |
| MainFactorProc | ${ORs[1]} | ${ESTs[1]} | ${SEs[1]} | ${Zs[1]} | ${Ps[1]} |
| Compl. | ${ORs[2]} | ${ESTs[2]} | ${SEs[2]} | ${Zs[2]} | ${Ps[2]} |
| Usage Freq. | ${ORs[3]} | ${ESTs[3]} | ${SEs[3]} | ${Zs[3]} | ${Ps[3]} |
| Approvals | ${ORs[4]} | ${ESTs[4]} | ${SEs[4]} | ${Zs[4]} | ${Ps[4]} |
| StudentTrue | ${ORs[5]} | ${ESTs[5]} | ${SEs[5]} | ${Zs[5]} | ${Ps[5]} |
| MainFactorProc:Compl. | ${ORs[6]} | ${ESTs[6]} | ${SEs[6]} | ${Zs[6]} | ${Ps[6]} |
EOT

# Run formatter for submission
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
