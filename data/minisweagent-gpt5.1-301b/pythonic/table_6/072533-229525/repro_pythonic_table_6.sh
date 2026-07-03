#!/usr/bin/bash
set -euo pipefail

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
cd /workspace
if [ ! -f ICSE2024-funcConstructs-Artifacts.zip ]; then
  curl -L 'https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1' \
    -o ICSE2024-funcConstructs-Artifacts.zip
fi

mkdir -p artifact
if [ ! -d artifact/ICSE2024-funcConstructs-Artifacts ]; then
  unzip -d artifact ICSE2024-funcConstructs-Artifacts.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
ARTIFACT_DIR="/workspace/artifact/ICSE2024-funcConstructs-Artifacts"
cd "$ARTIFACT_DIR"

# Ensure the Docker image is available
docker pull mdipenta/rexp

# Start a long-lived container if not already running
if ! docker ps --format '{{.Names}}' | grep -q '^rexp-shell$'; then
  if docker ps -a --format '{{.Names}}' | grep -q '^rexp-shell$'; then
    docker rm -f rexp-shell
  fi
  docker run -d --init --entrypoint bash -v"${ARTIFACT_DIR}:/data" \
    --name rexp-shell mdipenta/rexp -c 'sleep infinity'
fi

# Run the R analysis script inside the container to regenerate all tables
docker exec rexp-shell /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Extract and format Table 6 (map logistic regression) into /workspace/repro.txt
TABLE_CSV="$ARTIFACT_DIR/results/Table-6-RQ1-map.csv"
OUT_TXT="/workspace/repro.txt"

{
  echo '**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**'
  echo
  echo '| Term | Estimate | Std.Error | z value | Pr(>|z|) |'
  echo '|---|---:|---:|---:|---:|'
  awk -F',' '
    NR==2 { t="(Intercept)" }
    NR==3 { t="MainFactorProc" }
    NR==4 { t="Usage Freq." }
    NR==5 { t="Approvals" }
    NR==6 { t="StudentTrue" }
    NR>=2 && NR<=6 {
      printf("| %s | %.2f | %.2f | %.2f | %.2f |\n", t, $1, $2, $3, $4)
    }
  ' "$TABLE_CSV"
} > "$OUT_TXT"

# Section 4: Formatting and submission block
echo '<artisan_submit>'
echo '### Expected'
cat /workspace/expected.md
echo
echo '### Reproduced'
cat /workspace/repro.txt
echo '</artisan_submit>'
