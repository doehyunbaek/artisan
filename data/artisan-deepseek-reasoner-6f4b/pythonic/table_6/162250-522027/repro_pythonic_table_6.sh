#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | ??.?? | ????.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | -??.?? | ????.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull Docker image
docker pull mdipenta/rexp:latest
# Run container in detached mode
docker run -d --init --name analysis-container -v$(pwd)/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts:/data mdipenta/rexp:latest bash -c 'sleep infinity'
# Execute R script to generate tables
docker exec analysis-container bash -c 'cd /data && R --no-save < FuncConstructs-Statistics.r'
# Extract Table 6 results and format for comparison
docker exec analysis-container bash -c 'cat /data/results/Table-6-RQ1-map.csv' > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
