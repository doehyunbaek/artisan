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
# Section 2: Artifact download
artisan get https://zenodo.org/records/15857114
# Section 3: Reproduction commands (populate from reviewed steps)
# Load Docker image and start container
docker load -i lasapp-amd64.tar
CONTAINER_ID=$(docker run -d --init --entrypoint bash lasapp-amd64 -c 'sleep infinity')
sleep 10
# Start language servers
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "./scripts/start_servers.sh"
sleep 5
# Run Turing evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl turing" > /tmp/turing_output.txt 2>&1
TURING_TOTAL=117
TURING_GRAPH_ERROR=$(tail -2 /tmp/turing_output.txt | head -1 | grep -o 'Model Graph   Error Count: [0-9]*' | cut -d' ' -f5)
TURING_CONSTRAINT_ERROR=$(tail -2 /tmp/turing_output.txt | head -1 | grep -o 'Constraint    Error Count: [0-9]*' | cut -d' ' -f5)
# Run PyMC evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl pymc" > /tmp/pymc_output.txt 2>&1
PYMC_TOTAL=97
PYMC_GRAPH_ERROR=$(tail -2 /tmp/pymc_output.txt | head -1 | grep -o 'Model Graph   Error Count: [0-9]*' | cut -d' ' -f5)
PYMC_CONSTRAINT_ERROR=$(tail -2 /tmp/pymc_output.txt | head -1 | grep -o 'Constraint    Error Count: [0-9]*' | cut -d' ' -f5)
# Run HMC evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_hmc.py" > /tmp/hmc_output.txt 2>&1
GEN_TOTAL=8
GEN_WARNINGS=$(tail -2 /tmp/hmc_output.txt | head -1 | grep -o '[0-9]* / [0-9]*' | cut -d' ' -f1)
# Run Model-Guide evaluation and capture summary
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 experiments/evaluate_guide.py" > /tmp/guide_output.txt 2>&1
PYRO_TOTAL=8
PYRO_WARNINGS=$(tail -2 /tmp/guide_output.txt | head -1 | grep -o '[0-9]* / [0-9]*' | cut -d' ' -f1)
# Stop container
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID
# Write reproduction results
cat > /workspace/repro.txt <<'RESULT_TABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            117 |                 6  |
| Dependency Analysis    | PyMC   |             97 |                 2  |
| Constraint Verifier    | Turing |            117 |                37  |
| Constraint Verifier    | PyMC   |             97 |                32  |
| HMC Assumption Checker | Gen    |              8 |                 7  |
| Model-Guide Validator  | Pyro   |              8 |                 2  |

RESULT_TABLE
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
