#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -??.?? | ????.?? | ?.?? | ?.?? |
| MainFactorProc | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ??.?? | ????.?? | ?.?? | ?.?? |
EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
# Run the analysis using Docker
docker run -d --init --entrypoint bash -v${PWD}:/data mdipenta/rexp -c 'sleep infinity'
container_id=$(docker ps -lq)
docker exec $container_id /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Extract the table and format it
echo "**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**" > /workspace/repro.txt
echo "" >> /workspace/repro.txt
echo "| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |" >> /workspace/repro.txt
echo "|---|---:|---:|---:|---:|" >> /workspace/repro.txt
# Read the CSV and format each row
awk -F, 'NR==2 {printf "| (Intercept) | %.2f | %.2f | %.2f | %.2f |\n", $1, $2, $3, $4}' results/Table-8-RQ1-filter.csv >> /workspace/repro.txt
awk -F, 'NR==3 {printf "| MainFactorProc | %.2f | %.2f | %.2f | %.2f |\n", $1, $2, $3, $4}' results/Table-8-RQ1-filter.csv >> /workspace/repro.txt
awk -F, 'NR==4 {printf "| Usage Freq. | %.2f | %.2f | %.2f | %.2f |\n", $1, $2, $3, $4}' results/Table-8-RQ1-filter.csv >> /workspace/repro.txt
awk -F, 'NR==5 {printf "| Approvals | %.2f | %.2f | %.2f | %.2f |\n", $1, $2, $3, $4}' results/Table-8-RQ1-filter.csv >> /workspace/repro.txt
awk -F, 'NR==6 {printf "| StudentTrue | %.2f | %.2f | %.2f | %.2f |\n", $1, $2, $3, $4}' results/Table-8-RQ1-filter.csv >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
