#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            ??? |                 ?  |
| Dependency Analysis    | PyMC   |             ?? |                 ?  |
| Constraint Verifier    | Turing |            ??? |                 ?? |
| Constraint Verifier    | PyMC   |             ?? |                 ?? |
| HMC Assumption Checker | Gen    |              ? |                 ?  |
| Model-Guide Validator  | Pyro   |              ? |                 ?  |

EOTABLE
# Section 2: Artifact download (skip if already exists)
if [ ! -f "lasapp-amd64.tar" ]; then
    artisan get https://zenodo.org/records/15857114
fi
# Section 3: Reproduction commands
# Load Docker image and start container
docker load -i lasapp-amd64.tar
CONTAINER_ID=$(docker run -d --init --entrypoint bash lasapp-amd64 -c 'sleep infinity')
sleep 10
# Start language servers
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "./scripts/start_servers.sh"
sleep 5
# Run Turing evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl turing" > /tmp/turing_full.txt 2>&1
TURING_OUTPUT=$(tail -3 /tmp/turing_full.txt | head -2)
TURING_GRAPH_ERROR=$(echo "$TURING_OUTPUT" | grep "Model Graph" | sed -E 's/.*Error Count: ([0-9]+)\/.*/\1/')
TURING_CONSTRAINT_ERROR=$(echo "$TURING_OUTPUT" | grep "Constraint" | sed -E 's/.*Error Count: ([0-9]+)\/.*/\1/')
TURING_TOTAL=$(echo "$TURING_OUTPUT" | grep "Model Graph" | sed -E 's/.*Error Count: [0-9]+\/([0-9]+).*/\1/')
# Run PyMC evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl pymc" > /tmp/pymc_full.txt 2>&1
PYMC_OUTPUT=$(tail -3 /tmp/pymc_full.txt | head -2)
PYMC_GRAPH_ERROR=$(echo "$PYMC_OUTPUT" | grep "Model Graph" | sed -E 's/.*Error Count: ([0-9]+)\/.*/\1/')
PYMC_CONSTRAINT_ERROR=$(echo "$PYMC_OUTPUT" | grep "Constraint" | sed -E 's/.*Error Count: ([0-9]+)\/.*/\1/')
PYMC_TOTAL=$(echo "$PYMC_OUTPUT" | grep "Model Graph" | sed -E 's/.*Error Count: [0-9]+\/([0-9]+).*/\1/')
# Run HMC evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_hmc.py" > /tmp/hmc_full.txt 2>&1
HMC_OUTPUT=$(tail -2 /tmp/hmc_full.txt | head -1)
GEN_WARNINGS=$(echo "$HMC_OUTPUT" | grep -Eo '^[0-9]+' | head -1)
GEN_TOTAL=$(echo "$HMC_OUTPUT" | grep -Eo '[0-9]+$' | head -1)
# Run Model-Guide evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_guide.py" > /tmp/guide_full.txt 2>&1
GUIDE_OUTPUT=$(tail -2 /tmp/guide_full.txt | head -1)
PYRO_WARNINGS=$(echo "$GUIDE_OUTPUT" | grep -Eo '^[0-9]+' | head -1)
PYRO_TOTAL=$(echo "$GUIDE_OUTPUT" | grep -Eo '[0-9]+$' | head -1)
# Stop container
docker stop $CONTAINER_ID >/dev/null 2>&1
docker rm $CONTAINER_ID >/dev/null 2>&1
# Write reproduction results using extracted variables
cat > /workspace/repro.txt <<RESULT_TABLE
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            $TURING_TOTAL |                 $TURING_GRAPH_ERROR  |
| Dependency Analysis    | PyMC   |             $PYMC_TOTAL |                 $PYMC_GRAPH_ERROR  |
| Constraint Verifier    | Turing |            $TURING_TOTAL |                 $TURING_CONSTRAINT_ERROR  |
| Constraint Verifier    | PyMC   |             $PYMC_TOTAL |                 $PYMC_CONSTRAINT_ERROR  |
| HMC Assumption Checker | Gen    |              $GEN_TOTAL |                 $GEN_WARNINGS  |
| Model-Guide Validator  | Pyro   |              $PYRO_TOTAL |                 $PYRO_WARNINGS  |

RESULT_TABLE
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
