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
cd /workspace
curl -L "https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content" -o Cargo-Ecosystem-Monitor-ICSE.zip
unzip -q -o Cargo-Ecosystem-Monitor-ICSE.zip -d Cargo-Ecosystem-Monitor-ICSE
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
mkdir -p data
curl -L "https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1" -o data/Release-20220811.zip
cd data
unzip -q -o Release-20220811.zip
python - << 'PY' > /workspace/repro.txt
import csv
import os

base_dir = "/workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults"
path = os.path.join(base_dir, "mitigation_results.csv")

rows = 0
before_failure = 0
after_failure = 0

with open(path, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows += 1
        if row["before_status"] == "failure":
            before_failure += 1
        if row["after_mitigation"] == "failure":
            after_failure += 1

expected_total = 259540
expected_before_failure = 70913
expected_after_failure = 6978

if rows != expected_total or before_failure != expected_before_failure or after_failure != expected_after_failure:
    raise SystemExit(f"Unexpected values computed: total={rows}, before_failure={before_failure}, after_failure={after_failure}")

print("**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**\\n")
print("| RUF Impacts       |   Total | Compilation Failure |")
print("| ----------------- | ------: | ------------------: |")
print("| Before Mitigation | 259,540 |              70,913 |")
print("| After Mitigation  | 259,540 |               6,978 |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
