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
cd /workspace
artisan get https://zenodo.org/records/13744025
unzip -qo NeuroJIT.zip -d NeuroJIT
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NeuroJIT
docker-compose build
docker-compose run --rm neurojit-ase scripts/extract_pickles.sh
docker-compose run --rm neurojit-ase python scripts/jit_sdp.py actionable random_forest --display
docker-compose run --rm neurojit-ase python scripts/jit_sdp.py actionable xgboost --display
docker-compose run --rm neurojit-ase python scripts/analysis.py table-actionable data/output/actionable_random_forest.csv --fmt github > /workspace/repro.txt
docker-compose run --rm neurojit-ase python scripts/analysis.py table-actionable data/output/actionable_xgboost.csv --fmt github >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
