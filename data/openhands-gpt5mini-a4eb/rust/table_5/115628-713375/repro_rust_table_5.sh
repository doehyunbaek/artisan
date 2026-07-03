#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | 259,540 |              70,913 |
| After Mitigation  | 259,540 |               6,978 |

EOTABLE
# Section 2: Artifact download
curl -L -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip "https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content"
# Section 3: Reproduction commands (populate from reviewed steps)
# Extract the mitigation results CSV
unzip -p /workspace/Cargo-Ecosystem-Monitor-ICSE.zip "Cargo-Ecosystem-Monitor/Code/nightly_propagation/ruf_mitigation_analysis/mitigation_results.csv" > /workspace/mitigation_results.csv
# Compute totals
TOTAL=$(wc -l < /workspace/mitigation_results.csv)
BEFORE_FAILURE=$(awk -F, '$2=="failure"{c++} END{print c+0}' /workspace/mitigation_results.csv)
AFTER_FAILURE=$(awk -F, '$3=="failure"{c++} END{print c+0}' /workspace/mitigation_results.csv)
# Write reproduction results to repro.txt
cat > /workspace/repro.txt <<EOF
**Reproduced Table 5: RUF impact mitigation results (from mitigation_results.csv)**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | ${TOTAL} |           ${BEFORE_FAILURE} |
| After Mitigation  | ${TOTAL} |            ${AFTER_FAILURE} |
EOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
