#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Compl. | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc:Compl. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
docker rm -f funcconstructs || true
docker run -d --init --entrypoint bash -v${PWD}:/data --name funcconstructs mdipenta/rexp:latest -c 'sleep infinity'
docker exec funcconstructs /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
(echo "===== Table-4-RQ1-comp.txt =====" && cat results/Table-4-RQ1-comp.txt && echo "===== Table-4-RQ1-comp-coeff.txt =====" && cat results/Table-4-RQ1-comp-coeff.txt) > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
