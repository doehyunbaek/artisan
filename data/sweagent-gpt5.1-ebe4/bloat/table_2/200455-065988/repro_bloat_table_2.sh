#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved | 7,799,929 | 96.8% | 5,991 | 144.5 |
|  | Unresolved | 260,249 | 3.2% | 200 | 11.5 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o bloat-study-artifact-v1.0.zip https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip
unzip -q -o bloat-study-artifact-v1.0.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/gdrosos-bloat-study-artifact-0fe2fe5
pip install -r requirements.txt
python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'PYEOF'
import pandas as pd
from io import StringIO

with open('/workspace/repro.txt') as f:
    text = f.read().strip().splitlines()

header = text[0].split()
data_lines = text[1:3]
rows = []
for line in data_lines:
    parts = line.split()
    kind = parts[0]
    aggregate = parts[1]
    proportion = parts[2]
    avg = parts[3]
    median = parts[4]
    rows.append([kind, int(aggregate), float(proportion), float(avg), float(median)])

print('**Table 2 (reproduced): Statistics on the resolved and unresolved external calls during our stitching process.**\n')
print('|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |')
print('| --- | --- | --- | --- | --- | --- |')
print('|  |  |  |  |  |  |')
for kind, aggregate, proportion, avg, median in rows:
    print(f"|  | {kind} | {aggregate:,} | {proportion:.1f}% | {round(avg):,} | {median:.1f} |")
PYEOF
echo '</artisan_submit>'
