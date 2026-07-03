#!/usr/bin/bash
cd /workspace

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
docker pull mdipenta/rexp:latest

cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh

{
  echo '**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**'
  echo
  echo '| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |'
  echo '|---|---:|---:|---:|---:|'
  awk -F'&' '
    /\\\\/ && $0 !~ /Estimate/ && $0 !~ /hline/ {
      term=$1; est=$2; se=$3; z=$4; p=$5;
      gsub(/^[ \t]+|[ \t]+$/,"",term);
      gsub(/^[ \t]+|[ \t]+$/,"",est);
      gsub(/^[ \t]+|[ \t]+$/,"",se);
      gsub(/^[ \t]+|[ \t]+$/,"",z);
      gsub(/^[ \t]+|[ \t]+$/,"",p);
      gsub(/\\\\/,"",p);
      if (term=="MainFactorp") term="MainFactorProc";
      else if (term=="UsageFrequency") term="Usage Freq.";
      else if (term=="StudentTRUE") term="StudentTrue";
      print term "," est "," se "," z "," p;
    }
  ' results/Table-8-RQ1-filter.tex | while IFS=',' read -r term est se z p; do
    printf '| %s | %s | %s | %s | %s |\n' "$term" "$est" "$se" "$z" "$p"
  done
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
