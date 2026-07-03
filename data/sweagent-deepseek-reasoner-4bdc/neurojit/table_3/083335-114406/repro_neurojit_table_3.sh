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
echo "=== Downloading artifact from Zenodo ==="
cd /workspace
curl -L -o NeuroJIT.zip "https://zenodo.org/records/13744025/files/NeuroJIT.zip" || exit 1
unzip -q NeuroJIT.zip || exit 1

# Section 3: Reproduction commands
echo "=== Setting up environment and extracting data ==="
cd /workspace

# Build Docker image
echo "Building Docker image..."
docker build -t neurojit-ase . || exit 1

# Create container without starting the reproduce.sh script
echo "Creating Docker container..."
docker run -d --init --entrypoint bash --name neurojit-container neurojit-ase -c 'sleep infinity' || exit 1

# Extract pickles first
echo "Extracting pickles..."
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && scripts/extract_pickles.sh" || exit 1

# Run commands for Table 3
echo "=== Generating Table 3 results ==="
echo "** Generating LIME explanations for random forest and xgboost **"
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/jit_sdp.py actionable random_forest --display" 2>&1 | tee /workspace/repro_rf_actionable.txt
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/jit_sdp.py actionable xgboost --display" 2>&1 | tee /workspace/repro_xgb_actionable.txt

# Generate table outputs
echo "** Generating Table 3 outputs **"
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/analysis.py table-actionable data/output/actionable_random_forest.csv --fmt fancy_outline" 2>&1 | tee /workspace/repro_table_rf.txt
docker exec neurojit-container /bin/bash --noprofile --norc -c "cd /app && python scripts/analysis.py table-actionable data/output/actionable_xgboost.csv --fmt fancy_outline" 2>&1 | tee /workspace/repro_table_xgb.txt

# Combine outputs
cat > /workspace/repro.txt <<'EOREPRO'
Table 3 Reproduction Results:

Random Forest results:
EOREPRO
cat /workspace/repro_table_rf.txt >> /workspace/repro.txt
cat >> /workspace/repro.txt <<'EOREPRO'

XGBoost results:
EOREPRO
cat /workspace/repro_table_xgb.txt >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'

# Cleanup
docker stop neurojit-container
docker rm neurojit-container
