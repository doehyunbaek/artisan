#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 534.7  |
| **BIC**          | 566.3  |
| **logLik**       | -259.3 |
| **deviance**     | 518.7  |
| **df.residuals** | 378    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)* * User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

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
cd /workspace
curl -L https://zenodo.org/records/10554377 -o zenodo_10554377.html
curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1" -o ICSE2024-funcConstructs-Artifacts.zip
unzip -q ICSE2024-funcConstructs-Artifacts.zip -d artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
# Pull docker image with R and required packages
docker pull mdipenta/rexp:latest
# Start container in background following instructions
docker run -d --init --entrypoint bash --name funcconstructs_rexp -v${PWD}:/data mdipenta/rexp:latest -c 'sleep infinity'
# Run the R analysis script inside the container
docker exec funcconstructs_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Extract Table 4 results to /workspace/repro.txt
cd /workspace
{
  echo "MODEL SUMMARY (Table-4-RQ1-comp.txt)";
  sed -n '1,80p' artifact/ICSE2024-funcConstructs-Artifacts/results/Table-4-RQ1-comp.txt;
  echo;
  echo "COEFFICIENTS (Table-4-RQ1-comp-coeff.txt)";
  cat artifact/ICSE2024-funcConstructs-Artifacts/results/Table-4-RQ1-comp-coeff.txt;
} > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
