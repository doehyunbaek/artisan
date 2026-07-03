#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Average Ratios of Actionable Features within Top 5 Contribution Rankings of LIME Explanations**

| Project | Random Forest (%) | | XGBoost (%) |  | 
| --- | --- | --- | --- | --- |
| | baseline | combined (δ) | baseline | combined |  |
| ActiveMQ | 54.1 | 65.4 (l) | 59.0 | 70.7 (l) |
| Camel | 57.4 | 56.1 | 56.4 | 58.2 |
| Flink | 61.0 | 57.2 (s) | 38.7 | 59.3 (l) |
| Groovy | 25.3 | 54.4 (l) | 37.3 | 43.8 (s) |
| Cassandra | 53.8 | 68.5 (l) | 59.5 | 82.3 (l) |
| HBase | 52.1 | 58.4 (s) | 49.4 | 69.9 (l) |
| Hive | 58.2 | 60.8 (n) | 45.7 | 62.5 (l) |
| Ignite | 53.0 | 76.8 (l) | 47.2 | 61.9 (m) |
| Average (%) | 51.9 | 62.2 | 49.1 | 63.6 |

EOTABLE

# Section 2: Artifact download
# (artifact already included in the workspace for this run)
# curl -L -o NeuroJIT.zip "https://zenodo.org/records/13744025/files/NeuroJIT.zip"

# Section 3: Reproduction commands
cd /workspace/NeuroJIT_unpack
# Use the already-generated actionable CSVs and produce Table 3 outputs
rm -f /workspace/repro.txt
python3 scripts/analysis.py table-actionable data/output/actionable_random_forest.csv --fmt fancy_outline >> /workspace/repro.txt 2>&1
python3 scripts/analysis.py table-actionable data/output/actionable_xgboost.csv --fmt fancy_outline >> /workspace/repro.txt 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>' >> /workspace/repro.txt
# print the produced file
cat /workspace/repro.txt

echo '</artisan_submit>' >> /workspace/repro.txt
