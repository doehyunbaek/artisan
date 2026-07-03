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
# Download the replication package from Zenodo and unpack it.
curl -L -o /workspace/lasapp-main.zip "https://zenodo.org/records/15857114/files/lasapp-main.zip"
unzip -o /workspace/lasapp-main.zip -d /workspace/ || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Note: The repository provides scripts that expect Julia and Python language servers.
# The following commands implement the authors' documented reproduction steps.
set -e
cd /workspace/lasapp-main

# Install Python requirements (if running manually)
python3 -m pip install --user -r src/py/requirements.txt || true
# Instantiate Julia project (if julia is available)
julia --project=src/jl -e "using Pkg; Pkg.instantiate()" || true

# Start language servers (runs tmux sessions). If tmux/julia not available these commands may fail.
./scripts/start_servers.sh || true
# allow servers to start
sleep 3

# Run evaluations and collect outputs to /workspace/repro.txt
echo "---- EVALUATE: Turing (Model Graph + Constraint) ----" > /workspace/repro.txt
python3 experiments/evaluate_graph_and_constraints.py -ppl turing -analysis both >> /workspace/repro.txt 2>&1 || true

echo "---- EVALUATE: PyMC (Model Graph + Constraint) ----" >> /workspace/repro.txt
python3 experiments/evaluate_graph_and_constraints.py -ppl pymc -analysis both >> /workspace/repro.txt 2>&1 || true

echo "---- EVALUATE: Gen (HMC Assumption Checker) ----" >> /workspace/repro.txt
python3 experiments/evaluate_hmc.py >> /workspace/repro.txt 2>&1 || true

echo "---- EVALUATE: Pyro (Model-Guide Validator) ----" >> /workspace/repro.txt
python3 experiments/evaluate_guide.py >> /workspace/repro.txt 2>&1 || true

# Stop language servers
./scripts/stop_servers.sh || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Extract summary lines from repro.txt to make a small table. This is a best-effort formatting step.
awk '/Model Graph   Error Count:/ || /Constraint    Error Count:/ || /warnings\.|\/[0-9]+ warnings|in [0-9]+\.[0-9]+ seconds\./ {print}' /workspace/repro.txt || true

echo '</artisan_submit>'
