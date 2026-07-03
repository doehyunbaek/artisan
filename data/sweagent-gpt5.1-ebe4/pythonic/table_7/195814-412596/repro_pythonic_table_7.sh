#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -13.20 | 1696.36 | -0.01 | 0.99 |
| MainFactorProc | -0.26 | 0.47 | -0.56 | 0.99 |
| Usage Freq. | -0.83 | 0.44 | -1.87 | 0.30 |
| Approvals | 0.00 | 0.00 | -0.36 | 0.99 |
| StudentTrue | 14.38 | 1696.36 | 0.01 | 0.99 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o artifact.zip https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip
unzip -q artifact.zip -d artifact

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
# Pull Docker image with R environment
docker pull mdipenta/rexp:latest
# Start container in background with volume mounted
docker run -d --init --entrypoint bash --name func_rexp -v /workspace/artifact/ICSE2024-funcConstructs-Artifacts:/data mdipenta/rexp:latest -c 'sleep infinity'
# Run the analysis script inside the container
docker exec func_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Extract Table 7 (reduce) coefficients to repro.txt, adding Term names and rounding to match paper
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results
{
  echo "Term,Estimate,Std.Error,z value,Pr(>|z|)";
  awk -F',' 'NR==1 {next} NR==2 {term="(Intercept)"} NR==3 {term="MainFactorProc"} NR==4 {term="Usage Freq."} NR==5 {term="Approvals"} NR==6 {term="StudentTrue"} {
    if(NR>1){printf "%s,%.2f,%.2f,%.2f,%.2f\n", term,$1,$2,$3,$4}
  }' Table-7-RQ1-reduce.csv
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
