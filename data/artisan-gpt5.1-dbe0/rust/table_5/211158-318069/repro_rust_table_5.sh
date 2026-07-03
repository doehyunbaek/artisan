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
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor
mkdir -p data
curl 'https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1' --output data/Release-20220811.zip
cd data
unzip -o Release-20220811.zip
cd /workspace
python - << 'PY' > /workspace/repro.txt
import csv
from collections import Counter
from pathlib import Path

p = Path("Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/mitigation_results.csv")
total = 0
before = Counter()
after = Counter()
with p.open() as f:
    r = csv.DictReader(f)
    for row in r:
        total += 1
        before[row["before_status"]] += 1
        after[row["after_mitigation"]] += 1

before_total = total
after_total = total
before_failure = before.get("failure", 0)
after_failure = after.get("failure", 0)

print("**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**\n")
print("| RUF Impacts       |   Total | Compilation Failure |")
print("| ----------------- | ------: | ------------------: |")
print(f"| Before Mitigation | {before_total:,} | {before_failure:,} |")
print(f"| After Mitigation  | {after_total:,} | {after_failure:,} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
