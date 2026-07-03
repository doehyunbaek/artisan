#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Method Exit Anomalies**

| Program Name      |         #Failed |         Anomaly | Source-Code Oracle |
| ----------------- | --------------: | --------------: | -----------------: |
| commons-cli       | 13,965 (60.32%) |  4,216 (30.19%) |     1,728 (40.99%) |
| commons-text      | 17,832 (67.95%) |  4,985 (27.96%) |     1,882 (37.75%) |
| joda-money        | 36,495 (50.68%) | 10,486 (28.73%) |     5,931 (56.56%) |
| jline-reader      | 21,448 (19.36%) |  9,842 (45.89%) |     1,529 (15.54%) |
| commons-validator | 13,340 (51.42%) |  4,947 (37.08%) |     1,159 (23.43%) |
| cdk-data          | 80,398 (45.35%) | 38,550 (47.95%) |     5,717 (14.83%) |
| spotify-web-api   |  2,688 (34.19%) |    677 (25.19%) |          0 (0.00%) |
| commons-codec     | 18,097 (64.04%) |  5,250 (29.01%) |     1,195 (22.76%) |
| jfreechart        | 96,626 (37.92%) | 31,676 (32.78%) |    12,749 (40.25%) |
| dyn4j             | 89,603 (44.43%) | 47,065 (52.53%) |    22,324 (47.43%) |

EOTABLE
# Section 2: Artifact download
# (artifact already downloaded in this environment)
# Section 3: Reproduction commands
python3 - > /workspace/repro.txt <<'PY'
import csv
import os
os.chdir('/workspace')
bases = ["commons-cli","commons-text","joda-money","jline-reader","commons-validator","cdk-data","spotify-web-api","commons-codec","jfreechart","dyn4j"]
print("Program Name,#Failed,Anomaly,Source-Code Oracle")
for base in bases:
    path = base + '.csv'
    with open(path,newline='') as f:
        reader = csv.DictReader(f)
        non_return_rows = [row for row in reader if 'return' not in row['mutator']]
    a = len(non_return_rows)
    non_return_rows = [r for r in non_return_rows if r['test_status']=='fail']
    failings = len(non_return_rows)
    anomaly_rows = [r for r in non_return_rows if (r['mr_exception']!= r['nmr_exception']) or (r['mr_athrow']!= r['nmr_athrow']) or (r['mr_return']!= r['nmr_return'])]
    athrow_rows = [r for r in anomaly_rows if r['mr_athrow']=='1' or r['mr_athrow']=='1.0']
    b = len(anomaly_rows)
    c = len(athrow_rows)
    print(f"{base},{failings},{b},{c}")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
