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
curl -L -o /workspace/artifact.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content"
unzip -q /workspace/artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
chmod +x run-analysis.sh
./run-analysis.sh 2>&1 > /workspace/analysis.log
# Extract the reproduction results
cat results/Table-5-RQ1-mrf.txt > /workspace/repro.txt
echo "" >> /workspace/repro.txt
echo "Fixed effects with OR:" >> /workspace/repro.txt
cat results/Table-5-RQ1-mrf-coeff.txt >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# We'll format the output to match expected table style
# Let's create a simple formatted version using awk
cat results/Table-5-RQ1-mrf.txt | head -30 | sed -n '/^[[:space:]]*AIC[[:space:]]*BIC/,/^[[:space:]]*Random effects:/p' > /workspace/table_part1.txt
cat results/Table-5-RQ1-mrf-coeff.txt | tail -5 | awk -F',' '{printf "| %s | %.2f | %.2f | %.2f | %.2f | %.2f |\n", $1, $2, $3, $4, $5, $6}' > /workspace/table_part2.txt
echo '</artisan_submit>'
