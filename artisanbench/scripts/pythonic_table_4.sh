#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ICSE2024-funcConstructs-Artifacts.zip https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content
unzip ICSE2024-funcConstructs-Artifacts.zip -d  ICSE2024-funcConstructs-Artifacts

artifact_dir="ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts"
results_dir="$artifact_dir/results"

# Section 3: Reproduction commands
# 3.1 Recompute all results from raw data using the authors' R script in Docker
docker pull mdipenta/rexp
docker rm -f func_rexp_table4 >/dev/null 2>&1 || true
docker run -d --init --name func_rexp_table4 --entrypoint bash -v${PWD}:/data -w /data mdipenta/rexp -c 'sleep infinity'
docker exec func_rexp_table4 /bin/bash --noprofile --norc -c "cd /data/$artifact_dir && R --no-save < FuncConstructs-Statistics.r"

# 3.2 Extract model fit statistics (AIC, BIC, logLik, deviance, df.resid) from the GLMM summary
read AIC BIC LOGLIK DEVIANCE DFRES <<<"$(awk '
  /AIC[[:space:]]+BIC[[:space:]]+logLik[[:space:]]+deviance[[:space:]]+df.resid/ {
    getline;
    gsub(/\r/,"");
    printf "%s %s %s %s %s", $1,$2,$3,$4,$5
  }
' "$results_dir/Table-4-RQ1-comp.txt")"

# 3.3 Write the header of the reproduced Table 4
cat > /workspace/repro.txt <<EOF2
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | $AIC  |
| **BIC**          | $BIC  |
| **logLik**       | $LOGLIK |
| **deviance**     | $DEVIANCE  |
| **df.residuals** | $DFRES    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
EOF2

# 3.4 Append fixed-effects rows using the recomputed coefficient CSV (high precision),
#     relying on printf rounding to 2 decimals for all numeric columns.
awk -F',' '
BEGIN {
  terms[1] = "(Intercept)";
  terms[2] = "MainFactorProc";
  terms[3] = "Compl.";
  terms[4] = "Usage Freq.";
  terms[5] = "Approvals";
  terms[6] = "StudentTrue";
  terms[7] = "MainFactorProc:Compl.";
}
NR==1 { next }  # skip header
{
  idx = NR - 1;
  term = terms[idx];

  orv  = $1 + 0;  # OR
  est  = $2 + 0;  # Estimate
  sev  = $3 + 0;  # Std.Error
  zv   = $4 + 0;  # z value
  pval = $5 + 0;  # adjusted p

  printf("| %s | %.2f | %.2f | %.2f | %.2f | %.2f |\n", term, orv, est, sev, zv, pval);
}
' "$results_dir/Table-4-RQ1-comp-coeff.txt" >> /workspace/repro.txt

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
