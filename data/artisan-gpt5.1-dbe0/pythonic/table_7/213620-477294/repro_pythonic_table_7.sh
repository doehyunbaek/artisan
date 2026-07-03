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

# Run the R analysis inside Docker to regenerate all result files, including Table-7-RQ1-reduce.csv
sh run-analysis.sh

# Build the reproduced Table 7 in Markdown format from the CSV produced by the R script
{
  echo "**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**"
  echo
  echo "| Term | Estimate | Std.Error | z value | Pr(>|z|) |"
  echo "|---|---:|---:|---:|---:|"
  awk -F',' 'NR==1 {next}
    NR==2 {term="(Intercept)"}
    NR==3 {term="MainFactorProc"}
    NR==4 {term="Usage Freq."}
    NR==5 {term="Approvals"}
    NR==6 {term="StudentTrue"}
    NR>=2 && NR<=6 {
      # $1=Estimate, $2="Std. Error", $3="z value", $4="Pr(>|z|)"
      printf("| %s | %s | %s | %s | %s |\n", term, $1, $2, $3, $4)
    }' results/Table-7-RQ1-reduce.csv
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
