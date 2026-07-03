#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 443.0  |
| **BIC**          | 465.6  |
| **logLik**       | -215.5 |
| **deviance**     | 431.0 |
| **df.residuals** | 314    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.64 | 0.50 | 0.96 | 0.52 | 0.93 |
| MainFactorProc | 0.95 | -0.05 | 0.23 | -0.23 | 0.93 |
| Usage Freq. | 0.74 | -0.30 | 0.18 | -1.60 | 0.55 |
| Approvals | 1.00 | -0.00 | 0.00 | -0.29 | 0.93 |
| StudentTrue | 0.94 | -0.07 | 0.76 | -0.09 | 0.93 |

EOTABLE

# Section 2: Artifact download
curl -L -o /workspace/ICSE2024-funcConstructs-Artifacts.zip 'https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1'

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract artifact
unzip -o /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace

# Pull docker image
docker pull mdipenta/rexp:latest

# Start detached container (if container exists, remove first)
docker rm -f rexp_shell 2>/dev/null || true
docker run -d --init --entrypoint bash -v /workspace/ICSE2024-funcConstructs-Artifacts:/data --name rexp_shell mdipenta/rexp -c 'sleep infinity'

# Run the R analysis inside the container
docker exec rexp_shell /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Copy the Table 5 textual results out to repro.txt
docker cp rexp_shell:/data/results/Table-5-RQ1-mrf.txt /workspace/repro.txt || true

# Stop and remove container
docker stop rexp_shell 2>/dev/null || true
docker rm rexp_shell 2>/dev/null || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
if [ -f /workspace/repro.txt ]; then
    sed -n '1,200p' /workspace/repro.txt
else
    echo 'ERROR: reproduction output /workspace/repro.txt not found.'
fi
echo '</artisan_submit>'
