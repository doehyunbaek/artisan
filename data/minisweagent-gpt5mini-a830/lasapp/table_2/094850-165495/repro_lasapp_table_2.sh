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
mkdir -p /workspace/artifact
cd /workspace/artifact

# Download docker images and repository archive (if available)
curl -L -o lasapp-amd64.tar 'https://zenodo.org/records/15857114/files/lasapp-amd64.tar?download=1' || true
curl -L -o lasapp-arm64.tar 'https://zenodo.org/records/15857114/files/lasapp-arm64.tar?download=1' || true
curl -L -o lasapp-main.zip 'https://zenodo.org/records/15857114/files/lasapp-main.zip?download=1' || true

# Extract repository for potential docker build fallback
unzip -o lasapp-main.zip -d lasapp-main >/dev/null 2>&1 || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Prefer docker load; if not present try to build the image from the repo.
if [ -f /workspace/artifact/lasapp-amd64.tar ]; then
  docker load -i /workspace/artifact/lasapp-amd64.tar || true
fi

IMAGE=lasapp-amd64
docker image inspect "$IMAGE" >/dev/null 2>&1 || IMAGE=lasapp

# If the expected image is not present, attempt to build from extracted repository
docker image inspect "$IMAGE" >/dev/null 2>&1 || (cd /workspace/artifact/lasapp-main/lasapp-main && docker build -t lasapp .) || true

# Run container detached with sleep infinity (use --entrypoint bash as instructed)
docker run -d --init --entrypoint bash --name lasapp-container "$IMAGE" -c 'sleep infinity' || (docker run -d --init --entrypoint bash --name lasapp-container lasapp -c 'sleep infinity') || true

# Start language servers inside container (as README instructs)
docker exec lasapp-container /bin/bash --noprofile --norc -c "./scripts/start_servers.sh" || true
sleep 3

# Run the evaluation scripts and capture outputs to /workspace/repro.txt
# Each command appends to the same file so the final file contains all results.
docker exec lasapp-container /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl turing" > /workspace/repro.txt 2>&1 || true
docker exec lasapp-container /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl pymc" >> /workspace/repro.txt 2>&1 || true
docker exec lasapp-container /bin/bash --noprofile --norc -c "python3 experiments/evaluate_hmc.py" >> /workspace/repro.txt 2>&1 || true
docker exec lasapp-container /bin/bash --noprofile --norc -c "python3 experiments/evaluate_guide.py" >> /workspace/repro.txt 2>&1 || true

# Stop language servers and cleanup container
docker exec lasapp-container /bin/bash --noprofile --norc -c "./scripts/stop_servers.sh" || true
docker stop lasapp-container >/dev/null 2>&1 || true
docker rm lasapp-container >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'
