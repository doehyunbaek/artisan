#!/usr/bin/bash
set -euo pipefail

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

# Section 3: Reproduction commands (non-Docker approach)
# Ensure NeuroJIT has a LICENSE for editable install
if [ -f /workspace/LICENSE ] && [ -d /workspace/NeuroJIT ]; then
  cp /workspace/LICENSE /workspace/NeuroJIT/ || true
fi

# Install Python dependencies: prefer repository requirements if available
if [ -f /workspace/NeuroJIT/requirements.txt ]; then
  python -m pip install -r /workspace/NeuroJIT/requirements.txt
else
  python -m pip install typing_extensions typer rich pandas numpy click tabulate matplotlib seaborn scikit-learn xgboost lime statsmodels cliffs_delta
fi

# Install the NeuroJIT package in editable mode
python -m pip install -e /workspace/NeuroJIT

# Run analysis scripts to generate Table 3 outputs and capture to /workspace/repro.txt
python /workspace/NeuroJIT/scripts/analysis.py table-actionable /workspace/NeuroJIT/data/output/actionable_random_forest.csv --fmt fancy_outline > /workspace/repro.txt
python /workspace/NeuroJIT/scripts/analysis.py table-actionable /workspace/NeuroJIT/data/output/actionable_xgboost.csv --fmt fancy_outline >> /workspace/repro.txt

# Section 4: Formatting
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
