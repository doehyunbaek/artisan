#!/usr/bin/bash
set -euo pipefail
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -15.80 | 1383.44 | 0.01 | 0.99 |
| MainFactorProc | -0.06 | 0.40 | -0.16 | 0.99 |
| Usage Freq. | -0.18 | 0.33 | -0.54 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.76 | 0.99 |
| StudentTrue | 15.56 | 1383.44 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
ARTIFACT_URL="https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip"
ARTIFACT_ZIP="/workspace/ICSE2024-funcConstructs-Artifacts.zip"
ARTIFACT_DIR="/workspace/artifact"
mkdir -p "$ARTIFACT_DIR"
if [ ! -f "$ARTIFACT_ZIP" ]; then
  echo "Downloading artifact..."
  curl -sSL -o "$ARTIFACT_ZIP" "$ARTIFACT_URL"
fi
if [ ! -d "$ARTIFACT_DIR/ICSE2024-funcConstructs-Artifacts" ]; then
  echo "Unzipping artifact..."
  unzip -q "$ARTIFACT_ZIP" -d "$ARTIFACT_DIR"
fi

# Section 3: Reproduction commands
# This script attempts to reproduce Table 8 by running the provided R script inside the docker image mdipenta/rexp.
# It follows the artifact README instructions but uses a detached container and docker exec to run the R command.

WORKDIR="$ARTIFACT_DIR/ICSE2024-funcConstructs-Artifacts"
cd "$WORKDIR"

# Pull the docker image (if docker is available)
if command -v docker >/dev/null 2>&1; then
  echo "Docker found. Pulling mdipenta/rexp:latest..."
  docker pull mdipenta/rexp:latest || true

  # Run container in detached mode with the current working dir mounted at /data
  CONTAINER_NAME="repro_rexp_container"
  # remove any existing container with the same name
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
  docker run -d --init -v"${PWD}:/data" --workdir /data --name "$CONTAINER_NAME" --entrypoint bash mdipenta/rexp:latest -c 'sleep infinity'

  echo "Executing R script inside container... (this may take some minutes if image needs setup)"
  docker exec "$CONTAINER_NAME" /bin/bash --noprofile --norc -c "R --no-save < FuncConstructs-Statistics.r" || true

  echo "Copying resulting Table-8-RQ1-filter.csv to /workspace/repro.txt if produced"
  if [ -f "results/Table-8-RQ1-filter.csv" ]; then
    sed -n '1,200p' results/Table-8-RQ1-filter.csv > /workspace/repro.txt
  elif [ -f "Table-8-RQ1-filter.csv" ]; then
    sed -n '1,200p' Table-8-RQ1-filter.csv > /workspace/repro.txt
  else
    echo "results/Table-8-RQ1-filter.csv not found. Listing results/ dir:" > /workspace/repro.txt
    ls -la results >> /workspace/repro.txt 2>&1 || true
  fi

  # Stop and remove the container
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

else
  echo "Docker not available. Cannot run the R reproduction here." > /workspace/repro.txt
  echo "You can reproduce locally by running: ./run-analysis.sh in the artifact directory (it pulls mdipenta/rexp and runs the R script)." >> /workspace/repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
if [ -f /workspace/repro.txt ]; then
  cat /workspace/repro.txt
else
  echo 'No reproduction output found.'
fi
echo '</artisan_submit>'
