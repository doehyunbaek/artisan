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
cd data
if [ ! -d Release-20220811 ]; then
  curl 'https://zenodo.org/records/8289280/files/Release-20220811.zip?download=1' --output Release-20220811.zip
  unzip -o Release-20220811.zip
fi
cd /workspace
python - << 'PY'
import csv, collections, pathlib

path = pathlib.Path("Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/data/Release-20220811/ResearchResults/mitigation_results.csv")
counts_before = collections.Counter()
counts_after = collections.Counter()
total = 0
with path.open() as f:
    r = csv.DictReader(f)
    for row in r:
        total += 1
        counts_before[row["before_status"]] += 1
        counts_after[row["after_mitigation"]] += 1

before_failure = counts_before.get("failure", 0)
after_failure = counts_after.get("failure", 0)

with open("/workspace/repro.txt", "w") as out:
    out.write("**Table 5: RUF impact mitigation results. Applying our mitigation strategy, 90% of package versions can recover from compilation failure.**\n\n")
    out.write("| RUF Impacts       |   Total | Compilation Failure |\n")
    out.write("| ----------------- | ------: | ------------------: |\n")
    out.write(f"| Before Mitigation | {total:,} | {before_failure:>14,} |\n")
    out.write(f"| After Mitigation  | {total:,} | {after_failure:>14,} |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
