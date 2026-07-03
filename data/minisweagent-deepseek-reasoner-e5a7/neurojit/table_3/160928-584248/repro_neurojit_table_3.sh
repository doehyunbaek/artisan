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
curl -L -o /workspace/NeuroJIT.zip "https://zenodo.org/api/records/13744025/files/NeuroJIT.zip/content"
unzip -q /workspace/NeuroJIT.zip -d /workspace/NeuroJIT
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NeuroJIT
docker build -t neurojit-ase . > /dev/null 2>&1
docker run -d --init --name neurojit-container -v /workspace/NeuroJIT/data:/app/data -v /workspace/NeuroJIT/archive:/app/archive neurojit-ase bash -c 'sleep infinity'
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && scripts/extract_pickles.sh"
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/jit_sdp.py actionable random_forest --display" > /workspace/rf_actionable.log 2>&1
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/jit_sdp.py actionable xgboost --display" > /workspace/xgb_actionable.log 2>&1
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/analysis.py table-actionable data/output/actionable_random_forest.csv --fmt fancy_outline" > /workspace/repro.txt 2>&1
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/analysis.py table-actionable data/output/actionable_xgboost.csv --fmt fancy_outline" >> /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
