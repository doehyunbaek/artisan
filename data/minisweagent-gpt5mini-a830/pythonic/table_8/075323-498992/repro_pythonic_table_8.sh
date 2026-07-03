#!/usr/bin/bash
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
echo "Downloading artifact..."
curl -L -o /workspace/ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content"

echo "Unzipping artifact..."
unzip -o /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/ >/dev/null 2>&1 || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Use Dockerized R image as recommended. Follow replacement pattern for docker run.
IMAGE="mdipenta/rexp:latest"
CONTAINER_NAME="repro_rexp"

echo "Pulling docker image ${IMAGE} (may be skipped if present)..."
docker pull "${IMAGE}" || true

# Start container detached with /workspace mounted to /data, using the recommended entrypoint replacement
echo "Starting detached container ${CONTAINER_NAME}..."
docker run -d --init --entrypoint bash -v /workspace:/data --name "${CONTAINER_NAME}" "${IMAGE}" -c 'sleep infinity' || true

# Execute R script inside container; redirect output to a log
echo "Running R analysis inside container..."
docker exec "${CONTAINER_NAME}" /bin/bash --noprofile --norc -c "cd /data/ICSE2024-funcConstructs-Artifacts && R --no-save < FuncConstructs-Statistics.r" > /workspace/repro_r_output.log 2>&1 || true

# Stop and remove container
docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Collect reproduction results for Table 8 into /workspace/repro.txt
echo "Collecting Table 8 outputs..."
: > /workspace/repro.txt

# Search for files that likely contain Table 8 (by filename or content)
FOUND=0
# Look for files with table8 or table*8 in name under the artifact folder (case-insensitive)
while IFS= read -r -d '' f; do
  echo "----- FILE: $f -----" >> /workspace/repro.txt
  sed -n '1,200p' "$f" >> /workspace/repro.txt
  echo >> /workspace/repro.txt
  FOUND=1
done < <(find /workspace/ICSE2024-funcConstructs-Artifacts -type f \( -iname '*table*8*' -o -iname '*table8*' \) -print0 2>/dev/null)

# If not found by name, search results directory for CSV/TEX/TXT and try to pick relevant one(s)
if [ "$FOUND" -eq 0 ]; then
  while IFS= read -r -d '' f; do
    # Grep for "Table 8" inside files (common in .tex or .csv descriptions)
    if grep -i -q "Table 8" "$f" 2>/dev/null || head -n3 "$f" | tr -d '\r' | grep -qi 'term\|estimate\|Pr('; then
      echo "----- FILE: $f -----" >> /workspace/repro.txt
      sed -n '1,200p' "$f" >> /workspace/repro.txt
      echo >> /workspace/repro.txt
      FOUND=1
    fi
  done < <(find /workspace/ICSE2024-funcConstructs-Artifacts -type f \( -iname '*.csv' -o -iname '*.tex' -o -iname '*.txt' \) -print0 2>/dev/null)
fi

if [ "$FOUND" -eq 0 ]; then
  echo "Table 8 not found in generated results. See R execution log at /workspace/repro_r_output.log" > /workspace/repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>' >> /workspace/repro.txt
cat /workspace/repro.txt
echo '</artisan_submit>' >> /workspace/repro.txt

echo "Reproduction script completed. Results (or diagnostics) are in /workspace/repro.txt and the R log is in /workspace/repro_r_output.log"
