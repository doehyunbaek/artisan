#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        99.39% |    99.76% | 98.93% |  99.35% |
| Popular      |        99.50% |    100.00% | 99.17% |  99.58% |
| Mostdep      |        97.04% |    99.96% | 97.49% |  98.71% |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/artifact
curl -sSL -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip 'https://zenodo.org/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip?download=1'
unzip -o /workspace/Cargo-Ecosystem-Monitor-ICSE.zip -d /workspace/artifact

# Section 3: Reproduction commands
# Build docker image (preferred per README)
docker build -t cargo-ecosystem-monitor /workspace/artifact/Cargo-Ecosystem-Monitor

# Ensure any previous container is removed, then run detached with /workspace mounted so outputs are accessible
docker rm -f cargo_ecosystem_monitor_container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name cargo_ecosystem_monitor_container --mount type=bind,src=/workspace,target=/workspace cargo-ecosystem-monitor -c 'sleep infinity'

# Execute the evaluation summary inside the container and write results to /workspace/repro.txt
docker exec cargo_ecosystem_monitor_container /bin/bash --noprofile --norc -c '. "$HOME/.cargo/env" && cd /app/Code/accuracy_evaluation && unzip -o EDG_Evaluation_20220811.zip -d . >/dev/null 2>&1 || true && cargo run --bin summary_release > /workspace/repro.txt 2>&1'

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Print the reproduced resolution accuracy summary (if present) for submission
if grep -q "Resolution Accuracy Summary" /workspace/repro.txt; then
  sed -n '/Resolution Accuracy Summary:/,$p' /workspace/repro.txt
else
  echo "Reproduction output not found. See /workspace/repro.txt for details."
  echo
  cat /workspace/repro.txt 2>/dev/null || true
fi
echo '</artisan_submit>'
