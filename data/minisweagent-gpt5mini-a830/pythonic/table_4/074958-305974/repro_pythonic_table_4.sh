#!/usr/bin/bash
set -e
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 534.7  |
| **BIC**          | 566.3  |
| **logLik**       | -259.3 |
| **deviance**     | 518.7 |
| **df.residuals** | 378    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.15 | 0.14 | 0.89 | 0.16 | 0.88 |
| MainFactorProc | 6.11 | 1.81 | 0.60 | 3.00 | 0.02 |
| Compl. | 1.02 | 0.02 | 0.11 | 0.15 | 0.88 |
| Usage Freq. | 0.86 | -0.15 | 0.16 | -0.94 | 0.61 |
| Approvals | 1.00 | -0.00 | 0.00 | -1.12 | 0.61 |
| StudentTrue | 1.19 | 0.18 | 0.66 | 0.27 | 0.88 |
| MainFactorProc:Compl. | 0.65 | -0.43 | 0.17 | -2.58 | 0.03 |

EOTABLE

# Section 2: Artifact download
ARTIFACT_ZIP="/workspace/ICSE2024-funcConstructs-Artifacts.zip"
ARTIFACT_DIR="/workspace/artifact/ICSE2024-funcConstructs-Artifacts"
ARTIFACT_URL="https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip"

# download artifact (idempotent)
if [ ! -f "$ARTIFACT_ZIP" ]; then
    curl -L -o "$ARTIFACT_ZIP" "$ARTIFACT_URL"
fi

# extract
mkdir -p /workspace/artifact
unzip -o "$ARTIFACT_ZIP" -d /workspace/artifact

# Section 3: Reproduction commands
# Pull docker image
docker pull mdipenta/rexp:latest

# Run detached container (mount artifact folder)
docker rm -f rexp_container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash -v "$ARTIFACT_DIR":/data --name rexp_container mdipenta/rexp:latest -c 'sleep infinity'

# Execute the R analysis inside container (this will populate results/ under the mounted directory)
docker exec rexp_container /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Collect Table 4 outputs into /workspace/repro.txt
RESULTS_DIR="$ARTIFACT_DIR/results"
REPRO_OUT="/workspace/repro.txt"
: > "$REPRO_OUT"

# Include the textual diagnostics file (contains AIC/BIC/logLik/deviance etc.)
if [ -f "$RESULTS_DIR/Table-4-RQ1-comp.txt" ]; then
    echo "===== Table-4-RQ1-comp.txt (diagnostics and summary) =====" >> "$REPRO_OUT"
    cat "$RESULTS_DIR/Table-4-RQ1-comp.txt" >> "$REPRO_OUT"
    echo -e "\n" >> "$REPRO_OUT"
fi

# Include the coefficients CSV (contains OR and fixed effects as in the paper)
if [ -f "$RESULTS_DIR/Table-4-RQ1-comp-coeff.txt" ]; then
    echo "===== Table-4-RQ1-comp-coeff.txt (coefficients with OR) =====" >> "$REPRO_OUT"
    cat "$RESULTS_DIR/Table-4-RQ1-comp-coeff.txt" >> "$REPRO_OUT"
    echo -e "\n" >> "$REPRO_OUT"
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>' >> "$REPRO_OUT"
echo '---BEGIN_REPRODUCTION_OUTPUT---' >> "$REPRO_OUT"
cat "$REPRO_OUT" >> "$REPRO_OUT" || true
echo '---END_REPRODUCTION_OUTPUT---' >> "$REPRO_OUT"
echo '</artisan_submit>' >> "$REPRO_OUT"

# For convenience, also print the reproduction summary to stdout when running the script
echo '<artisan_submit>'
if [ -f "$REPRO_OUT" ]; then
    sed -n '1,200p' "$REPRO_OUT" || true
else
    echo "Reproduction output not found."
fi
echo '</artisan_submit>'

