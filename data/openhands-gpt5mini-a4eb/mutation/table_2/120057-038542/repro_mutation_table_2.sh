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
# Download artifact (RIPR-framework.zip) from Zenodo
curl -L -o /workspace/RIPR-framework.zip "https://zenodo.org/api/records/10505175/files/RIPR-framework.zip/content"

# Section 3: Reproduction commands (populate from reviewed steps)
# Unzip relevant files and extract CSV datasets and scripts
unzip -o /workspace/RIPR-framework.zip "RIPR-framework-Zenodo/data/*" -d /workspace/RIPR-framework
unzip -o /workspace/RIPR-framework.zip "RIPR-framework-Zenodo/scripts/*" -d /workspace/RIPR-framework
mkdir -p /workspace/RIPR-framework/data_unzipped
unzip -o /workspace/RIPR-framework/RIPR-framework-Zenodo/data/cdkdata_cli_codec_text_validator.zip -d /workspace/RIPR-framework/data_unzipped
unzip -o /workspace/RIPR-framework/RIPR-framework-Zenodo/data/jyn4j_jfreechart_jline_jodamoney_spotify.zip -d /workspace/RIPR-framework/data_unzipped

# Run a small Python snippet to compute the Table 2 values and write to /workspace/repro.txt
python3 - <<'PY'
import pandas as pd
bases = ["commons-cli","commons-text","joda-money","jline-reader","commons-validator","cdk-data","spotify-web-api","commons-codec","jfreechart","dyn4j"]
lines = []
for base in bases:
    path = f"/workspace/RIPR-framework/data_unzipped/{base}.csv"
    df = pd.read_csv(path)
    non_return = df[~df["mutator"].str.contains("return")]
    a = len(non_return)
    non_return = non_return[non_return["test_status"]=="fail"]
    failings = len(non_return)
    anomaly = non_return[(non_return["mr_exception"]!= non_return["nmr_exception"]) | (non_return["mr_athrow"]!= non_return["nmr_athrow"]) | (non_return["mr_return"]!= non_return["nmr_return"]) ]
    athrow = anomaly[anomaly["mr_athrow"]==1]
    b = (len(anomaly)/len(non_return))*100 if len(non_return)>0 else 0
    c = (len(athrow)/len(anomaly))*100 if len(anomaly)>0 else 0
    lines.append((base, failings, a, len(anomaly), len(athrow), b, c))
with open('/workspace/repro.txt','w') as f:
    for base, failings, a, anom, athrow, b, c in lines:
        f.write(f"{base:<18} | {failings:7,} ({failings/a * 100:6.2f}%) | {anom:7,} ({b:6.2f}%) | {athrow:7,} ({c:6.2f}%)\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
