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
echo "Downloading artifact..."
if [ ! -f /workspace/lasapp-main.zip ]; then
    wget -q -c https://zenodo.org/records/15857114/files/lasapp-main.zip -O /workspace/lasapp-main.zip
fi
if [ ! -f /workspace/lasapp-amd64.tar ]; then
    wget -q -c https://zenodo.org/records/15857114/files/lasapp-amd64.tar/content -O /workspace/lasapp-amd64.tar
fi
if [ ! -d /workspace/lasapp-main ]; then
    unzip -q /workspace/lasapp-main.zip -d /workspace
fi

# Load docker image
echo "Loading Docker image..."
docker load -i /workspace/lasapp-amd64.tar > /dev/null 2>&1

# Clean up any existing container
docker stop lasapp-container > /dev/null 2>&1 || true
docker rm lasapp-container > /dev/null 2>&1 || true

# Start container
echo "Starting container..."
docker run -d --init --name lasapp-container lasapp-amd64 bash -c 'sleep infinity'

# Wait a bit for container to be ready
sleep 2

# Start language servers
echo "Starting language servers..."
docker exec -w /LASAPP lasapp-container ./scripts/start_servers.sh > /dev/null 2>&1
sleep 2

# Verify servers are running
if ! docker exec lasapp-container tmux ls 2>&1 | grep -q "ls-jl"; then
    echo "Language servers failed to start."
    exit 1
fi

# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running experiments..."
# Turing
docker exec -w /LASAPP lasapp-container python3 experiments/evaluate_graph_and_constraints.py -ppl turing 2>&1 | tee /workspace/turing_out.txt
# PyMC
docker exec -w /LASAPP lasapp-container python3 experiments/evaluate_graph_and_constraints.py -ppl pymc 2>&1 | tee /workspace/pymc_out.txt
# HMC
docker exec -w /LASAPP lasapp-container python3 experiments/evaluate_hmc.py 2>&1 | tee /workspace/hmc_out.txt
# Guide
docker exec -w /LASAPP lasapp-container python3 experiments/evaluate_guide.py 2>&1 | tee /workspace/guide_out.txt

# Stop container
docker stop lasapp-container > /dev/null 2>&1
docker rm lasapp-container > /dev/null 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Extract numbers
turing_graph=$(grep "Model Graph.*Error Count" /workspace/turing_out.txt | awk '{print $5}' | cut -d'/' -f1)
turing_constraint=$(grep "Constraint.*Error Count" /workspace/turing_out.txt | awk '{print $5}' | cut -d'/' -f1)
pymc_graph=$(grep "Model Graph.*Error Count" /workspace/pymc_out.txt | awk '{print $5}' | cut -d'/' -f1)
pymc_constraint=$(grep "Constraint.*Error Count" /workspace/pymc_out.txt | awk '{print $5}' | cut -d'/' -f1)
hmc_warnings=$(grep -E "[0-9]+ / [0-9]+ warnings" /workspace/hmc_out.txt | awk '{print $1}')
guide_warnings=$(grep -E "[0-9]+ / [0-9]+ warnings" /workspace/guide_out.txt | awk '{print $1}')

# Print reproduced table
echo "**Table 2: Summary tables of evaluation results (reproduced).**"
echo ""
echo "| Analysis               | PPL    | Total Programs | Warnings produced  |"
echo "| ---------------------- | ------ | -------------: | ----------------:  |"
echo "| Dependency Analysis    | Turing |            117 |                 $turing_graph  |"
echo "| Dependency Analysis    | PyMC   |             97 |                 $pymc_graph  |"
echo "| Constraint Verifier    | Turing |            117 |                 $turing_constraint |"
echo "| Constraint Verifier    | PyMC   |             97 |                 $pymc_constraint |"
echo "| HMC Assumption Checker | Gen    |              8 |                 $hmc_warnings  |"
echo "| Model-Guide Validator  | Pyro   |              8 |                 $guide_warnings  |"
echo ""
echo '</artisan_submit>'