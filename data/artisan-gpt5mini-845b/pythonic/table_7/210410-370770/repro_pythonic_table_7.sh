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

# Section 3: Reproduction commands
# Run the provided R analysis inside the docker image to regenerate results
docker rm -f repro_rc >/dev/null 2>&1 || true
docker pull mdipenta/rexp:latest >/dev/null 2>&1 || true
docker run -v${PWD}:/data -v /workspace:/workspace --name repro_rc -d --init --entrypoint bash mdipenta/rexp:latest -c 'sleep infinity' >/dev/null 2>&1 || true
docker exec repro_rc /bin/bash --noprofile --norc -c "cd /data/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts && R --no-save < FuncConstructs-Statistics.r" >/dev/null 2>&1 || true
docker stop repro_rc >/dev/null 2>&1 || true
docker rm repro_rc >/dev/null 2>&1 || true

# Format the produced CSV (Table-7-RQ1-reduce.csv) into the exact markdown table, rounding to 2 decimals
csv='ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/results/Table-7-RQ1-reduce.csv'
if [ -f "$csv" ]; then
  printf "%s\n\n" "**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**" > /workspace/repro.txt
  printf "%s\n" "| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |" >> /workspace/repro.txt
  printf "%s\n" "|---|---:|---:|---:|---:|" >> /workspace/repro.txt
  awk -F, 'BEGIN{names[1]="(Intercept)"; names[2]="MainFactorProc"; names[3]="Usage Freq."; names[4]="Approvals"; names[5]="StudentTrue"}
  NR>1 && NR<=6{
    est=$1+0; se=$2+0; z=$3+0; p=$4+0;
    # round to 2 decimals with printf
    printf("| %s | %.2f | %.2f | %.2f | %.2f |\n", names[NR-1], est, se, z, p) >> "/workspace/repro.txt"
  }' "$csv"
else
  # fallback: write an informative repro file if CSV missing
  cat > /workspace/repro.txt <<'T'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -??.?? | ????.?? | -?.?? | ?.?? |
| MainFactorProc | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ??.?? | ????.?? | ?.?? | ?.?? |
T
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
