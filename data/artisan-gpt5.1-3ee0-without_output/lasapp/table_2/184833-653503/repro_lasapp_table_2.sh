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

# Load the prebuilt AMD64 Docker image and start a long-running container.
docker load -i lasapp-amd64.tar
docker run -d --init --entrypoint bash --name lasapp-amd64 --rm lasapp-amd64 -c 'sleep infinity'

# Start language servers inside the container.
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && ./scripts/start_servers.sh"

# Run Dependency Analysis and Constraint Verifier for Turing and PyMC, capturing logs.
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl turing" | tee /workspace/turing.log
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_graph_and_constraints.py -ppl pymc"   | tee /workspace/pymc.log

# Run HMC Assumption Checker for Gen.
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_hmc.py"   | tee /workspace/hmc.log

# Run Model-Guide Validator for Pyro.
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && python3 experiments/evaluate_guide.py" | tee /workspace/guide.log

# Parse Turing summary: "Model Graph   Error Count: 6/117" and "Constraint    Error Count: 37/117"
turing_graph_line=$(grep "Model Graph   Error Count" /workspace/turing.log)
turing_constraint_line=$(grep "Constraint    Error Count" /workspace/turing.log)

turing_graph_counts=$(echo "$turing_graph_line" | awk -F':' '{print $2}')
turing_graph_counts=${turing_graph_counts//[[:space:]]/}
turing_graph_warnings=${turing_graph_counts%/*}
turing_total=${turing_graph_counts#*/}

turing_constraint_counts=$(echo "$turing_constraint_line" | awk -F':' '{print $2}')
turing_constraint_counts=${turing_constraint_counts//[[:space:]]/}
turing_constraint_warnings=${turing_constraint_counts%/*}

# Parse PyMC summary: "Model Graph   Error Count: 2/97" and "Constraint    Error Count: 32/97"
pymc_graph_line=$(grep "Model Graph   Error Count" /workspace/pymc.log)
pymc_constraint_line=$(grep "Constraint    Error Count" /workspace/pymc.log)

pymc_graph_counts=$(echo "$pymc_graph_line" | awk -F':' '{print $2}')
pymc_graph_counts=${pymc_graph_counts//[[:space:]]/}
pymc_graph_warnings=${pymc_graph_counts%/*}
pymc_total=${pymc_graph_counts#*/}

pymc_constraint_counts=$(echo "$pymc_constraint_line" | awk -F':' '{print $2}')
pymc_constraint_counts=${pymc_constraint_counts//[[:space:]]/}
pymc_constraint_warnings=${pymc_constraint_counts%/*}

# Parse HMC summary: line of form "7 / 8 warnings."
hmc_line=$(grep "warnings." /workspace/hmc.log | tail -n 1)
hmc_warnings=$(echo "$hmc_line" | awk '{print $1}')
hmc_total=$(echo "$hmc_line" | awk '{print $3}')

# Parse Model-Guide summary: line of form "2 / 8 warnings."
guide_line=$(grep "warnings." /workspace/guide.log | tail -n 1)
guide_warnings=$(echo "$guide_line" | awk '{print $1}')
guide_total=$(echo "$guide_line" | awk '{print $3}')

# Write the reproduced table to /workspace/repro.txt
cat > /workspace/repro.txt <<EOTABLE
**Table 2: Summary tables of evaluation results.**

| Analysis               | PPL    | Total Programs | Warnings produced  |
| ---------------------- | ------ | -------------: | ----------------:  |
| Dependency Analysis    | Turing |            $turing_total |                 $turing_graph_warnings  |
| Dependency Analysis    | PyMC   |             $pymc_total |                 $pymc_graph_warnings  |
| Constraint Verifier    | Turing |            $turing_total |                 $turing_constraint_warnings  |
| Constraint Verifier    | PyMC   |             $pymc_total |                 $pymc_constraint_warnings  |
| HMC Assumption Checker | Gen    |              $hmc_total |                 $hmc_warnings  |
| Model-Guide Validator  | Pyro   |              $guide_total |                 $guide_warnings  |

EOTABLE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
