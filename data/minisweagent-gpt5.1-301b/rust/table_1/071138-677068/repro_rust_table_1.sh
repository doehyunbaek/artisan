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
set -euo pipefail
ARTIFACT_ZIP="/workspace/Cargo-Ecosystem-Monitor-ICSE.zip"
ARTIFACT_DIR="/workspace/Cargo-Ecosystem-Monitor-ICSE"
REPO_DIR="$ARTIFACT_DIR/Cargo-Ecosystem-Monitor"

curl -L -o "$ARTIFACT_ZIP" "https://zenodo.org/api/records/10496086/files/Cargo-Ecosystem-Monitor-ICSE.zip/content"
mkdir -p "$ARTIFACT_DIR"
unzip -o -d "$ARTIFACT_DIR" "$ARTIFACT_ZIP"

# Section 3: Reproduction commands (populate from reviewed steps)
cd "$REPO_DIR"

# Initialize submodules (crates.io-index and modified rustc)
make submodule

# Build Docker image as per README
docker build -t cargo-ecosystem-monitor .

# Run Docker container (modified per instructions: detached, --init, entrypoint bash + sleep)
# Expose Postgres on 12345 and bind-mount the project at /app
docker rm -f cargo-ecosystem-monitor-container >/dev/null 2>&1 || true
docker run -d --init --name cargo-ecosystem-monitor-container \
  -p 127.0.0.1:12345:5432 \
  -e POSTGRES_PASSWORD="postgres" \
  -w /app \
  --mount type=bind,src="$(pwd)",target=/app \
  --entrypoint bash \
  cargo-ecosystem-monitor -c 'sleep infinity'

# Setup PostgreSQL in the container
docker exec cargo-ecosystem-monitor-container /bin/bash --noprofile --norc -c "cd /app && make postgresql"

# Extract precomputed accuracy evaluation results
docker exec cargo-ecosystem-monitor-container /bin/bash --noprofile --norc -c "cd /app/Code/accuracy_evaluation && unzip -o EDG_Evaluation_20220811.zip"

# Run summary_release to get resolution accuracy summary; capture to file
docker exec cargo-ecosystem-monitor-container /bin/bash --noprofile --norc -c "cd /app/Code/accuracy_evaluation && cargo run --bin summary_release > summary_release.txt"

# Copy the summary output to the required location
cp "$REPO_DIR/Code/accuracy_evaluation/summary_release.txt" /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - <<'PY'
import re
from pathlib import Path

text = Path("/workspace/repro.txt").read_text(encoding="utf-8")

datasets = {}
current = None

for line in text.splitlines():
    line = line.strip()
    if line.startswith("Dataset:"):
        key = line.split(":", 1)[1].strip().lower()
        datasets[key] = {}
        current = datasets[key]
    elif line.startswith("Tree Accuracy"):
        m = re.search(r"= ([0-9.]+)%", line)
        if m and current is not None:
            current["Tree Accuracy"] = float(m.group(1))
    elif line.startswith("Precision"):
        m = re.search(r"= ([0-9.]+)%", line)
        if m and current is not None:
            current["Precision"] = float(m.group(1))
    elif line.startswith("Recall"):
        m = re.search(r"= ([0-9.]+)%", line)
        if m and current is not None:
            current["Recall"] = float(m.group(1))
    elif line.startswith("F1Score"):
        m = re.search(r"= ([0-9.]+)%", line)
        if m and current is not None:
            current["F1Score"] = float(m.group(1))

order = ["random", "popular", "mostdep"]
display_name = {"random": "Random", "popular": "Popular", "mostdep": "Mostdep"}

print("**Table 1: Resolution accuracy.**\n")
print("| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |")
print("| ------------ | ------------: | --------: | -----: | ------: |")

for key in order:
    d = datasets.get(key, {})
    ta = d.get("Tree Accuracy", 0.0)
    pr = d.get("Precision", 0.0)
    rc = d.get("Recall", 0.0)
    f1 = d.get("F1Score", 0.0)
    # Format to two decimal places to match the paper
    print(f"| {display_name[key]:-12} | {ta:10.2f}% | {pr:9.2f}% | {rc:6.2f}% |  {f1:6.2f}% |")
PY
echo '</artisan_submit>'
