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
curl -L -o /workspace/artifact.zip https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip
unzip -q /workspace/artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp
container_id=$(docker run -d --init --entrypoint bash -v /workspace/artifact/ICSE2024-funcConstructs-Artifacts:/data mdipenta/rexp -c 'sleep infinity')
sleep 5
docker exec "$container_id" /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Output the reproduction results to /workspace/repro.txt
cp /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-7-RQ1-reduce.csv /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the output table
terms=("(Intercept)" "MainFactorProc" "Usage Freq." "Approvals" "StudentTrue")
i=0
while IFS=, read -r estimate stderr zvalue pvalue
do
  if [ $i -eq 0 ]; then
    i=$((i+1))
    continue
  fi
  term="${terms[$((i-1))]}"
  # Round values to two decimal places
  estimate_rounded=$(printf "%.2f" "$estimate")
  stderr_rounded=$(printf "%.2f" "$stderr")
  zvalue_rounded=$(printf "%.2f" "$zvalue")
  pvalue_rounded=$(printf "%.2f" "$pvalue")
  echo "| $term | $estimate_rounded | $stderr_rounded | $zvalue_rounded | $pvalue_rounded |"
  i=$((i+1))
done < /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-7-RQ1-reduce.csv
echo '</artisan_submit>'
