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
# Download and extract the artifact from Zenodo
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
# Run the analysis inside Docker and format Table 7 into /workspace/repro.txt
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp
sh run-analysis.sh
# Build the reproduction markdown table from the generated CSV
cat > /workspace/repro.txt <<'EOTABLE2'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
EOTABLE2
awk -F',' 'NR==1{next}
NR==2{term="(Intercept)"}
NR==3{term="MainFactorProc"}
NR==4{term="Usage Freq."}
NR==5{term="Approvals"}
NR==6{term="StudentTrue"}
NR>=2 && NR<=6{
  printf("| %s | %s | %s | %s | %s |\n",term,$1,$2,$3,$4)
}' results/Table-7-RQ1-reduce.csv >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the reproduction output table against the expected table
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
