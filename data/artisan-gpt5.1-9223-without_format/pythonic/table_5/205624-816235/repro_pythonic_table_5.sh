#!/usr/bin/bash
set -e

# Section 1: Expected table (obfuscated template)
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

artifact_root="ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts"
readme_path="$artifact_root/README.md"
results_dir="$artifact_root/results"

# Section 3: Reproduction commands

# 3a: Locate docker and (if any) Table 5 mentions in README, as required
if [ -f "$readme_path" ]; then
  grep -in docker "$readme_path" || true
  grep -in "Table 5" "$readme_path" || true
fi

# 3b: Run the official analysis script (Dockerized R) to (re)generate results/
cd "$artifact_root"
sh run-analysis.sh
cd /workspace

# 3c: Parse the regenerated MRF mixed-effects model outputs to build Table 5
mrf_txt="$results_dir/Table-5-RQ1-mrf.txt"
mrf_coeff_csv="$results_dir/Table-5-RQ1-mrf-coeff.txt"

# Extract model fit statistics
stats_line=$(awk '/^     AIC/ {getline; gsub(/^ +/, "", $0); print; exit}' "$mrf_txt")
set -- $stats_line
AIC_VAL=$1
BIC_VAL=$2
LOGLIK_VAL=$3
DEVIANCE_VAL=$4
DFRES_VAL=$5

# Extract scaled residuals line and round to two decimals
res_line=$(awk '/Scaled residuals:/ {getline; getline; gsub(/^ +/, "", $0); print; exit}' "$mrf_txt")
set -- $res_line
MIN_RAW=$1
Q1_RAW=$2
MED_RAW=$3
Q3_RAW=$4
MAX_RAW=$5

MIN_VAL=$(printf "%.2f" "$MIN_RAW")
Q1_VAL=$(printf "%.2f" "$Q1_RAW")
MED_VAL=$(printf "%.2f" "$MED_RAW")
Q3_VAL=$(printf "%.2f" "$Q3_RAW")
MAX_VAL=$(printf "%.2f" "$MAX_RAW")

# Build the markdown table into repro.txt
{
  echo "**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**"
  echo
  echo "|                  |        |"
  echo "| ---------------- | ------ |"
  printf "| **AIC**          | %.1f  |\n" "$AIC_VAL"
  printf "| **BIC**          | %.1f  |\n" "$BIC_VAL"
  printf "| **logLik**       | %.1f |\n" "$LOGLIK_VAL"
  printf "| **deviance**     | %.1f  |\n" "$DEVIANCE_VAL"
  printf "| **df.residuals** | %d    |\n" "$DFRES_VAL"
  echo
  printf "**Scaled residuals:** Min %s, 1Q %s, Median %s, 3Q %s, Max %s\n" "$MIN_VAL" "$Q1_VAL" "$MED_VAL" "$Q3_VAL" "$MAX_VAL"
  echo
  echo "**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159"
  echo
  echo "**Fixed effects**"
  echo
  echo "| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |"
  echo "|---|---:|---:|---:|---:|---:|"

  idx=0
  tail -n +2 "$mrf_coeff_csv" | while IFS=, read -r OR EST SE Z P; do
    idx=$((idx+1))
    case "$idx" in
      1) name="(Intercept)";;
      2) name="MainFactorProc";;
      3) name="Usage Freq.";;
      4) name="Approvals";;
      5) name="StudentTrue";;
      *) continue;;
    esac
    OR_F=$(printf "%.2f" "$OR")
    EST_F=$(printf "%.2f" "$EST")
    SE_F=$(printf "%.2f" "$SE")
    Z_F=$(printf "%.2f" "$Z")
    P_F=$(printf "%.2f" "$P")
    printf "| %s | %s | %s | %s | %s | %s |\n" "$name" "$OR_F" "$EST_F" "$SE_F" "$Z_F" "$P_F"
  done
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
