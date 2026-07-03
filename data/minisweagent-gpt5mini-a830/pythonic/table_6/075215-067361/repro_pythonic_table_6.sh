#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | 16.48 | 1370.51 | 0.01 | 0.99 |
| MainFactorProc | 0.67 | 0.48 | 1.39 | 0.82 |
| Usage Freq. | -0.03 | 0.38 | -0.09 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.07 | 0.99 |
| StudentTrue | -15.75 | 1370.51 | -0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
set -e
cd /workspace
ART_ZIP="/workspace/ICSE2024-funcConstructs-Artifacts.zip"
ART_DIR="/workspace/artifact/ICSE2024-funcConstructs-Artifacts"
if [ ! -f "$ART_ZIP" ]; then
  echo "Downloading artifact..."
  curl -L -o "$ART_ZIP" 'https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content'
fi
rm -rf "$ART_DIR"
unzip -o "$ART_ZIP" -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
# Use Docker image as suggested by the authors, but run container detached and exec the R script inside.
IMAGE="mdipenta/rexp:latest"
CONTAINER_NAME="repro_r_container_$$"
WORKDIR_HOST="/workspace/artifact/ICSE2024-funcConstructs-Artifacts"
WORKDIR_CONTAINER="/data"

# Pull image (preferred order)
docker pull "$IMAGE" || true

# Run detached container with the artifact mounted
docker run -d --init --entrypoint bash -v "${WORKDIR_HOST}:${WORKDIR_CONTAINER}" --name "$CONTAINER_NAME" "$IMAGE" -c 'sleep infinity'

# Execute the R analysis script inside the container (non-interactive, no profile)
docker exec "$CONTAINER_NAME" /bin/bash --noprofile --norc -c "cd ${WORKDIR_CONTAINER} && R --no-save < FuncConstructs-Statistics.r"

# Stop and remove the container
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Locate Table 6 output under results/ (try several common naming patterns). Write to /workspace/repro.txt
REPRO_OUT="/workspace/repro.txt"
RESULTS_DIR="${WORKDIR_HOST}/results"
rm -f "$REPRO_OUT"
mkdir -p "$(dirname "$REPRO_OUT")"

# Try to find files with table6 in name (case-insensitive)
TABLE6_FILE=$(find "$RESULTS_DIR" -type f -iname '*table*6*' -print -quit 2>/dev/null || true)

# Fallback: try files that mention "map" (the table concerns map) among CSV/TEX/TXT
if [ -z "$TABLE6_FILE" ]; then
  TABLE6_FILE=$(find "$RESULTS_DIR" -type f \( -iname '*.csv' -o -iname '*.tex' -o -iname '*.txt' \) -exec sh -c 'grep -Iq "map" "$1" && printf "%s\n" "$1"' _ {} \; | head -n1 || true)
fi

# Final fallback: pick any CSV in results (useful if naming differs)
if [ -z "$TABLE6_FILE" ]; then
  TABLE6_FILE=$(find "$RESULTS_DIR" -type f -iname '*.csv' -print -quit 2>/dev/null || true)
fi

if [ -n "$TABLE6_FILE" ]; then
  echo "Found candidate Table 6 file: $TABLE6_FILE" > "$REPRO_OUT"
  echo "----" >> "$REPRO_OUT"
  # If it's a binary/tex, still dump as text
  sed -n '1,200p' "$TABLE6_FILE" >> "$REPRO_OUT" 2>/dev/null || cat "$TABLE6_FILE" >> "$REPRO_OUT"
else
  echo "ERROR: Could not locate Table 6 output in ${RESULTS_DIR}" > "$REPRO_OUT"
  echo "Contents of ${RESULTS_DIR}:" >> "$REPRO_OUT"
  ls -la "$RESULTS_DIR" >> "$REPRO_OUT" 2>&1 || true
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>' 
cat "$REPRO_OUT"
echo '</artisan_submit>'
