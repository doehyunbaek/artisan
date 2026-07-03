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
# Download the artifact zip from Zenodo and unzip it into /workspace/NeuroJIT
curl -L -o /workspace/NeuroJIT.zip "https://zenodo.org/api/records/13744025/files/NeuroJIT.zip/content"
unzip -q /workspace/NeuroJIT.zip -d /workspace/NeuroJIT

# Section 3: Reproduction commands
# Build the docker-compose image, run the reproduce script to generate outputs,
# then run the analysis.py commands that produce the Table 3 related outputs.
# The results are written to /workspace/repro.txt
cd /workspace/NeuroJIT
docker-compose build
docker-compose run --rm neurojit-ase scripts/reproduce.sh
# Generate Random Forest table-set-relationships (Table 3)
docker-compose run --rm neurojit-ase python scripts/analysis.py table-set-relationships data/output/random_forest_cuf.json data/output/random_forest_baseline.json --fmt fancy_outline --no-only-tp > /workspace/repro.txt
# Generate XGBoost table-set-relationships (Table 3)
docker-compose run --rm neurojit-ase python scripts/analysis.py table-set-relationships data/output/xgboost_cuf.json data/output/xgboost_baseline.json --fmt fancy_outline --no-only-tp >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_formatted.txt
cat /workspace/repro.txt >> /workspace/repro_formatted.txt
echo '</artisan_submit>' >> /workspace/repro_formatted.txt

