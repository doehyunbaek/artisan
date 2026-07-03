#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: RQ1: Mixed-effect logistic regression relating the use of lambdas with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -1.98, 1Q -0.95, Median 0.49, 3Q 0.85, Max 1.44

**Random effects (Groups)** — User (Intercept): Variance 0.2381, Std.Dev. 0.4879; Number of obs: 322, groups: User, 160

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | -?.?? | ?.?? | -?.?? | <?.?? |
| Compl. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| MainFactorProc:Compl. | ?.?? | ?.?? | ?.?? | ?.?? | <?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands (populate from reviewed steps)
# Change to the extracted artifact directory
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts

# Pull the Docker image (acquire images in the documented order)
docker pull mdipenta/rexp:latest

# Ensure any previous container is removed, then run detached container per rules
docker rm -f rexp_submit >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name rexp_submit -v${PWD}:/data --workdir /data mdipenta/rexp:latest -c 'sleep infinity'

# Execute the analysis inside the container to generate results (Tables including Table 3)
docker exec rexp_submit /bin/bash --noprofile --norc -c "R --no-save < FuncConstructs-Statistics.r"

# Stop and remove the container
docker stop rexp_submit >/dev/null 2>&1 || true
docker rm rexp_submit >/dev/null 2>&1 || true

# Save the produced Table 3 textual output into /workspace/repro.txt
# (the analysis produces results/Table-3-RQ1-lambda.txt)
cat results/Table-3-RQ1-lambda.txt > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
