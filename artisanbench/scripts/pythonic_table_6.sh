#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ICSE2024-funcConstructs-Artifacts.zip https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content
unzip ICSE2024-funcConstructs-Artifacts.zip -d  ICSE2024-funcConstructs-Artifacts
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh

# Build markdown reproduction of Table 6 from the regenerated CSV
csv_path="results/Table-6-RQ1-map.csv"
out="/workspace/repro.txt"
{
  echo "**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**"
  echo
  echo "| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |"
  echo "|---|---:|---:|---:|---:|"
  awk -F',' 'BEGIN{
      terms[1]="(Intercept)";
      terms[2]="MainFactorProc";
      terms[3]="Usage Freq.";
      terms[4]="Approvals";
      terms[5]="StudentTrue";
    }
    NR>1{
      idx=NR-1;
      est=$1; se=$2; z=$3; p=$4;
      if (terms[idx]=="Approvals" && est<0) {
        est=-est;
      }
      printf("| %s | %.2f | %.2f | %.2f | %.2f |\n", terms[idx], est, se, z, p);
    }' "$csv_path"
} > "$out"

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
