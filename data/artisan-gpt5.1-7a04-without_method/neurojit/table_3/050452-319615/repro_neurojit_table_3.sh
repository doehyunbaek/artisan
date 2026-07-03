#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Average Ratios of Actionable Features within Top 5 Contribution Rankings of LIME Explanations**

| Project | Random Forest (%) | | XGBoost (%) |  | 
| --- | --- | --- | --- | --- |
| | baseline | combined (δ) | baseline | combined |  |
| ActiveMQ | ??.? | ??.? (l) | ??.? | ??.? (l) |
| Camel | ??.? | ??.? | ??.? | ??.? |
| Flink | ??.? | ??.? (s) | ??.? | ??.? (l) |
| Groovy | ??.? | ??.? (l) | ??.? | ??.? (s) |
| Cassandra | ??.? | ??.? (l) | ??.? | ??.? (l) |
| HBase | ??.? | ??.? (s) | ??.? | ??.? (l) |
| Hive | ??.? | ??.? (n) | ??.? | ??.? (l) |
| Ignite | ??.? | ??.? (l) | ??.? | ??.? (m) |
| Average (%) | ??.? | ??.? | ??.? | ??.? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13744025

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract the NeuroJIT replication package
unzip -qn NeuroJIT.zip -d NeuroJIT

# Build the Docker image
cd NeuroJIT
docker-compose build

# Run the actionable LIME workflow (with pickles extraction) and capture only the Table 3-related output
docker-compose run --rm neurojit-ase sh -lc "scripts/extract_pickles.sh && python scripts/jit_sdp.py actionable random_forest --display && python scripts/jit_sdp.py actionable xgboost --display && echo 'Random Forest' && python scripts/analysis.py table-actionable data/output/actionable_random_forest.csv --fmt fancy_outline && echo 'XGBoost' && python scripts/analysis.py table-actionable data/output/actionable_xgboost.csv --fmt fancy_outline" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
