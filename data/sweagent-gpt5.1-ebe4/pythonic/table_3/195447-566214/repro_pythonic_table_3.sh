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
curl -L -o ICSE2024-funcConstructs-Artifacts.zip 'https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1'
unzip -o ICSE2024-funcConstructs-Artifacts.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
# Pull Docker image with R and required packages
docker pull mdipenta/rexp:latest
# Start container in background, mounting artifact directory
docker run -d --init --entrypoint bash --name rexp_container -v${PWD}/ICSE2024-funcConstructs-Artifacts:/data mdipenta/rexp:latest -c 'sleep infinity'
# Run the R analysis script inside the container to generate results/Table 3
docker exec rexp_container /bin/bash --noprofile --norc -c 'cd /data && R --no-save < FuncConstructs-Statistics.r'
# Extract the lambda mixed-effects model summary and coefficients (Table 3) into repro.txt
cd /workspace/ICSE2024-funcConstructs-Artifacts/results
{
  echo "Generalized linear mixed model summary (lambda, Table 3 raw output):";
  cat Table-3-RQ1-lambda.txt;
  echo;
  echo "\nFixed effects with odds ratios (lambda, Table 3 coefficients):";
  echo "Term,OR,Estimate,Std.Error,z value,Pr(>|z|)";
  awk -F',' 'NR==2 {print "(Intercept),"$1","$2","$3","$4","$5"} \
               NR==3 {print "MainFactorProc,"$1","$2","$3","$4","$5"} \
               NR==4 {print "Compl.,"$1","$2","$3","$4","$5"} \
               NR==5 {print "Usage Freq.,"$1","$2","$3","$4","$5"} \
               NR==6 {print "Approvals,"$1","$2","$3","$4","$5"} \
               NR==7 {print "StudentTrue,"$1","$2","$3","$4","$5"} \
               NR==8 {print "MainFactorProc:Compl.,"$1","$2","$3","$4","$5"}' Table-3-RQ1-lambda-coeff.txt;
} > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
