#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: RQ1: Mixed-effect logistic regression relating the use of lambdas with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 438.3  |
| **BIC**          | 468.5  |
| **logLik**       | -211.2 |
| **deviance**     | 422.3  |
| **df.residuals** | 314    |

**Scaled residuals:** Min -1.98, 1Q -0.95, Median 0.49, 3Q 0.85, Max 1.44

**Random effects (Groups)** — User (Intercept): Variance 0.2370, Std.Dev. 0.4878; Number of obs: 322, groups: User, 160

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 3.72 | 1.31 | 1.13 | 1.17 | 0.24 |
| MainFactorProc | 0.11 | -2.19 | 0.67 | -3.29 | <0.01 |
| Compl. | 0.75 | -0.29 | 0.19 | -1.55 | 0.24 |
| Usage Freq. | 1.32 | 0.28 | 0.23 | 1.20 | 0.24 |
| Approvals | 1.00 | -0.00 | 0.00 | -1.41 | 0.24 |
| StudentTrue | 0.35 | -1.04 | 0.88 | -1.18 | 0.24 |
| MainFactorProc:Compl. | 2.67 | 0.98 | 0.28 | 3.56 | <0.01 |

EOTABLE

# Section 2: Artifact download
cd /workspace

if [ ! -f ICSE2024-funcConstructs-Artifacts.zip ]; then
  curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1" -o ICSE2024-funcConstructs-Artifacts.zip
fi

mkdir -p /workspace/ICSE2024-funcConstructs-Artifacts
unzip -o -d /workspace/ICSE2024-funcConstructs-Artifacts ICSE2024-funcConstructs-Artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts

# Pull the Docker image with R and required packages
docker pull mdipenta/rexp:latest

# Ensure a fresh container
if docker ps -a --format '{{.Names}}' | grep -q '^funcconstructs_rexp$'; then
  docker rm -f funcconstructs_rexp >/dev/null 2>&1 || true
fi

# Start a long-lived container
docker run -d --init --name funcconstructs_rexp -v "$(pwd)":/data mdipenta/rexp:latest bash -c 'sleep infinity'

# Run the R analysis script inside the container to regenerate results (including Table 3)
docker exec funcconstructs_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Stop and remove the container
docker stop funcconstructs_rexp >/dev/null 2>&1 || true
docker rm funcconstructs_rexp >/dev/null 2>&1 || true

# Collect reproduction output for Table 3 (lambda model) into /workspace/repro.txt
RESULTS_DIR="/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/results"

{
  echo "Table 3 reproduction - RQ1: Mixed-effect logistic regression relating the use of lambdas with the correctness of the change task"
  echo
  echo "=== Model summary (Table-3-RQ1-lambda.txt) ==="
  echo
  cat "${RESULTS_DIR}/Table-3-RQ1-lambda.txt"
  echo
  echo "=== Fixed effects with OR (Table-3-RQ1-lambda-coeff.txt) ==="
  echo
  cat "${RESULTS_DIR}/Table-3-RQ1-lambda-coeff.txt"
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
echo '--- Expected Table (expected.md) ---'
cat /workspace/expected.md
echo
echo '--- Reproduced Table 3 output (repro.txt) ---'
cat /workspace/repro.txt
echo '</artisan_submit>'
