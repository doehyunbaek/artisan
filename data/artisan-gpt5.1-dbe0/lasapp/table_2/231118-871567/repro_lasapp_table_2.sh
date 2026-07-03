#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            117 |                 6  |
| Dependency Analysis    | PyMC   |             97 |                 2  |
| Constraint Verifier    | Turing |            117 |                37  |
| Constraint Verifier    | PyMC   |             97 |                32  |
| HMC Assumption Checker | Gen    |              8 |                 7  |
| Model-Guide Validator  | Pyro   |              8 |                 2  |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/15857114
# Section 3: Reproduction commands (populate from reviewed steps)
# Load Docker image and start container
docker load -i lasapp-amd64.tar
docker run -d --init --name lasapp-amd64 --rm --entrypoint bash lasapp-amd64 -c 'sleep infinity'
# Start language servers
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/start_servers.sh"
# Run evaluations, capturing logs
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl turing > /LASAPP/turing_graph_constraints.log"
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl pymc > /LASAPP/pymc_graph_constraints.log"
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_hmc.py > /LASAPP/hmc_gen.log"
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_guide.py > /LASAPP/guide_pyro.log"
# Copy logs to workspace
docker cp lasapp-amd64:/LASAPP/. /workspace/lasapp_logs
# Stop container (optional, since --rm is set)
docker stop lasapp-amd64 || true
# Parse summary numbers
cd /workspace/lasapp_logs
# Turing stats
TURING_GRAPH_LINE=$(grep 'Model Graph   Error Count' turing_graph_constraints.log)
TURING_CONSTR_LINE=$(grep 'Constraint    Error Count' turing_graph_constraints.log)
TURING_GRAPH_WARN=$(echo "$TURING_GRAPH_LINE" | sed -E 's/.*Error Count: ([0-9]+)\/([0-9]+).*/\1/')
TURING_TOTAL=$(echo "$TURING_GRAPH_LINE" | sed -E 's/.*Error Count: ([0-9]+)\/([0-9]+).*/\2/')
TURING_CONSTR_WARN=$(echo "$TURING_CONSTR_LINE" | sed -E 's/.*Error Count: ([0-9]+)\/([0-9]+).*/\1/')
# PyMC stats
PYMC_GRAPH_LINE=$(grep 'Model Graph   Error Count' pymc_graph_constraints.log)
PYMC_CONSTR_LINE=$(grep 'Constraint    Error Count' pymc_graph_constraints.log)
PYMC_GRAPH_WARN=$(echo "$PYMC_GRAPH_LINE" | sed -E 's/.*Error Count: ([0-9]+)\/([0-9]+).*/\1/')
PYMC_TOTAL=$(echo "$PYMC_GRAPH_LINE" | sed -E 's/.*Error Count: ([0-9]+)\/([0-9]+).*/\2/')
PYMC_CONSTR_WARN=$(echo "$PYMC_CONSTR_LINE" | sed -E 's/.*Error Count: ([0-9]+)\/([0-9]+).*/\1/')
# HMC Gen stats
HMC_LINE=$(grep 'warnings\.' hmc_gen.log | tail -n 1)
HMC_WARN=$(echo "$HMC_LINE" | sed -E 's/^\s*([0-9]+)\s*\/\s*([0-9]+).*/\1/')
HMC_TOTAL=$(echo "$HMC_LINE" | sed -E 's/^\s*([0-9]+)\s*\/\s*([0-9]+).*/\2/')
# Pyro guide stats
GUIDE_LINE=$(grep 'warnings\.' guide_pyro.log | tail -n 1)
GUIDE_WARN=$(echo "$GUIDE_LINE" | sed -E 's/^\s*([0-9]+)\s*\/\s*([0-9]+).*/\1/')
GUIDE_TOTAL=$(echo "$GUIDE_LINE" | sed -E 's/^\s*([0-9]+)\s*\/\s*([0-9]+).*/\2/')
# Write reproduction table
cat > /workspace/repro.txt <<EOTABLE_REPRO
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing | $TURING_TOTAL | $TURING_GRAPH_WARN |
| Dependency Analysis    | PyMC   | $PYMC_TOTAL | $PYMC_GRAPH_WARN |
| Constraint Verifier    | Turing | $TURING_TOTAL | $TURING_CONSTR_WARN |
| Constraint Verifier    | PyMC   | $PYMC_TOTAL | $PYMC_CONSTR_WARN |
| HMC Assumption Checker | Gen    | $HMC_TOTAL | $HMC_WARN |
| Model-Guide Validator  | Pyro   | $GUIDE_TOTAL | $GUIDE_WARN |

EOTABLE_REPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
