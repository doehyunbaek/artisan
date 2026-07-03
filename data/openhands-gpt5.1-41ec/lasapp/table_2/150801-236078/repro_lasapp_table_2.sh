#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            117 |                 6  |
| Dependency Analysis    | PyMC   |             97 |                 2  |
| Constraint Verifier    | Turing |            117 |                 37 |
| Constraint Verifier    | PyMC   |             97 |                 32 |
| HMC Assumption Checker | Gen    |              8 |                 7  |
| Model-Guide Validator  | Pyro   |              8 |                 2  |

EOTABLE

# Section 2: Artifact download
cd /workspace

# Download main source archive if missing
if [ ! -f lasapp-main.zip ]; then
  curl -L "https://zenodo.org/api/records/15857114/files/lasapp-main.zip/content" -o lasapp-main.zip
fi

# Unpack source tree if missing
if [ ! -d lasapp-main ]; then
  unzip -o lasapp-main.zip
fi

# Download prebuilt Docker image (amd64) if missing
if [ ! -f lasapp-amd64.tar ]; then
  curl -L "https://zenodo.org/api/records/15857114/files/lasapp-amd64.tar/content" -o lasapp-amd64.tar
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/lasapp-main

# Load Docker image and start container
docker load -i ../lasapp-amd64.tar

# Run container in background using recommended detached pattern
docker run -d --init --name lasapp-amd64 --rm \
  --entrypoint bash lasapp-amd64 -c 'sleep infinity'

# Start language servers inside container
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c './scripts/start_servers.sh'

# Run evaluations, capturing logs on host
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c \
  'python3 experiments/evaluate_graph_and_constraints.py -ppl turing' \
  > /workspace/turing_eval.log

docker exec lasapp-amd64 /bin/bash --noprofile --norc -c \
  'python3 experiments/evaluate_graph_and_constraints.py -ppl pymc' \
  > /workspace/pymc_eval.log

docker exec lasapp-amd64 /bin/bash --noprofile --norc -c \
  'python3 experiments/evaluate_hmc.py' \
  > /workspace/hmc_eval.log

docker exec lasapp-amd64 /bin/bash --noprofile --norc -c \
  'python3 experiments/evaluate_guide.py' \
  > /workspace/guide_eval.log

# Parse Turing dependency and constraint results
TUR_GRAPH=$(grep 'Model Graph' /workspace/turing_eval.log | awk -F'Error Count:' '{print $2}' | tr -d ' ')
TUR_GRAPH_WARN=${TUR_GRAPH%%/*}
TUR_GRAPH_TOTAL=${TUR_GRAPH##*/}

TUR_CONST=$(grep '^Constraint' /workspace/turing_eval.log | awk -F'Error Count:' '{print $2}' | tr -d ' ')
TUR_CONST_WARN=${TUR_CONST%%/*}
TUR_CONST_TOTAL=${TUR_CONST##*/}

# Parse PyMC dependency and constraint results
PYMC_GRAPH=$(grep 'Model Graph' /workspace/pymc_eval.log | awk -F'Error Count:' '{print $2}' | tr -d ' ')
PYMC_GRAPH_WARN=${PYMC_GRAPH%%/*}
PYMC_GRAPH_TOTAL=${PYMC_GRAPH##*/}

PYMC_CONST=$(grep '^Constraint' /workspace/pymc_eval.log | awk -F'Error Count:' '{print $2}' | tr -d ' ')
PYMC_CONST_WARN=${PYMC_CONST%%/*}
PYMC_CONST_TOTAL=${PYMC_CONST##*/}

# Parse HMC assumption checker results
HMC_LINE=$(grep 'warnings\.' /workspace/hmc_eval.log | tail -n 1)
HMC_WARN=$(echo "$HMC_LINE" | awk '{print $1}')
HMC_TOTAL=$(echo "$HMC_LINE" | awk '{print $3}')

# Parse model-guide validator results
GUIDE_LINE=$(grep 'warnings\.' /workspace/guide_eval.log | tail -n 1)
GUIDE_WARN=$(echo "$GUIDE_LINE" | awk '{print $1}')
GUIDE_TOTAL=$(echo "$GUIDE_LINE" | awk '{print $3}')

# Write reproduced table to /workspace/repro.txt
cat > /workspace/repro.txt <<EOT
**Table 2: Summary tables of evaluation results (reproduced).**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing | $(printf "%12s" "$TUR_GRAPH_TOTAL") | $(printf "%17s" "$TUR_GRAPH_WARN") |
| Dependency Analysis    | PyMC   | $(printf "%12s" "$PYMC_GRAPH_TOTAL") | $(printf "%17s" "$PYMC_GRAPH_WARN") |
| Constraint Verifier    | Turing | $(printf "%12s" "$TUR_CONST_TOTAL") | $(printf "%17s" "$TUR_CONST_WARN") |
| Constraint Verifier    | PyMC   | $(printf "%12s" "$PYMC_CONST_TOTAL") | $(printf "%17s" "$PYMC_CONST_WARN") |
| HMC Assumption Checker | Gen    | $(printf "%12s" "$HMC_TOTAL") | $(printf "%17s" "$HMC_WARN") |
| Model-Guide Validator  | Pyro   | $(printf "%12s" "$GUIDE_TOTAL") | $(printf "%17s" "$GUIDE_WARN") |

EOT

# Stop the container (it will be removed because of --rm)
docker stop lasapp-amd64 >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
