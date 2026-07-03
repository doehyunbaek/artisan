#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -??.?? | ????.?? | -?.?? | ?.?? |
| MainFactorProc | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ??.?? | ????.?? | ?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
# Pull the Docker image and run the analysis
docker pull mdipenta/rexp
docker run -d --init --entrypoint bash -v$(pwd):/data --workdir /data --name rexp_container mdipenta/rexp -c 'sleep infinity'
docker exec rexp_container /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Copy the generated Table 7 to repro.txt
cat results/Table-7-RQ1-reduce.csv > /workspace/repro.txt
# Clean up
docker stop rexp_container && docker rm rexp_container
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
