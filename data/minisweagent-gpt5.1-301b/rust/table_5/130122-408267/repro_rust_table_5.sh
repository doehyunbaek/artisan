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
set -euo pipefail
cd /workspace
if [ ! -f Cargo-Ecosystem-Monitor-ICSE.zip ]; then
  curl -L "https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content" -o Cargo-Ecosystem-Monitor-ICSE.zip
fi
if [ ! -d Cargo-Ecosystem-Monitor ]; then
  unzip -q Cargo-Ecosystem-Monitor-ICSE.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor/Code/nightly_propagation/ruf_mitigation_analysis
set -- $(awk -F, 'NR>1{tot++; if($2=="failure") bf++; if($3=="failure") af++} END{printf "%d %d %d\n",tot,bf,af}' mitigation_results.csv)
total="$1"
before_failure="$2"
after_failure="$3"

cat > /workspace/repro.txt <<EOT
**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**

| RUF Impacts       |   Total | Compilation Failure |
| ----------------- | ------: | ------------------: |
| Before Mitigation | $total |              $before_failure |
| After Mitigation  | $total |               $after_failure |
EOT

# Section 4: Formatting and submission block
cd /workspace
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
