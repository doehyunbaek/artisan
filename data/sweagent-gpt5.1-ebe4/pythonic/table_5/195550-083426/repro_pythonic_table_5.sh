#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 443.0  |
| **BIC**          | 465.6  |
| **logLik**       | -215.5 |
| **deviance**     | 431.0  |
| **df.residuals** | 314    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)* * User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

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
curl -L 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content' -o /workspace/ICSE2024-funcConstructs-Artifacts.zip
unzip -o /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
# Pull docker image with R and required packages
docker pull mdipenta/rexp:latest
# Start container in background (no interactive TTY)
docker run -d --init --entrypoint bash --name rexp_container -v"${PWD}":/data mdipenta/rexp:latest -c 'sleep infinity'
# Run the R analysis script inside the container
docker exec rexp_container /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Extract the Table 5 mixed-effect logistic regression output to repro.txt
cd /workspace/ICSE2024-funcConstructs-Artifacts/results
sed -n '1,160p' Table-5-RQ1-mrf.txt > /workspace/repro.txt
# Section 4: Formatting and submission block
cd /workspace
echo '<artisan_submit>'
# For this artifact, the raw GLMM summary for MRF (Table 5) is our reproduction output.
cat /workspace/repro.txt
echo '</artisan_submit>'
