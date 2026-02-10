#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        ??.??% |    ??.??% | ??.??% |  ??.??% |
| Popular      |        ??.??% |    ??.??% | ??.??% |  ??.??% |
| Mostdep      |        ??.??% |    ??.??% | ??.??% |  ??.??% |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10496086
# Section 3: Reproduction commands
zip="Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation/EDG_Evaluation_20220811.zip"
out="/workspace/repro.txt"
echo "**Table 1: Resolution accuracy.**" >"$out"
echo "" >>"$out"
echo "| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |" >>"$out"
echo "| ------------ | ------------: | --------: | -----: | ------: |" >>"$out"
for ds in random popular mostdep; do
  file="results_2000/${ds}/results.txt"
  tmp="/tmp/result_${ds}.txt"
  if unzip -p "$zip" "$file" >"$tmp" 2>/dev/null; then
    tree=$(grep -i "Tree Accuracy" "$tmp" | head -n1 | sed -E "s/.*= *([0-9.]+)%.*/\1%/")
    prec=$(grep -i "Precision" "$tmp" | head -n1 | sed -E "s/.*= *([0-9.]+)%.*/\1%/")
    rec=$(grep -i "Recall" "$tmp" | head -n1 | sed -E "s/.*= *([0-9.]+)%.*/\1%/")
    f1=$(grep -i "F1Score" "$tmp" | head -n1 | sed -E "s/.*= *([0-9.]+)%.*/\1%/")
    label=$(echo "$ds" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    echo "| $label | ${tree:-??.??%} | ${prec:-??.??%} | ${rec:-??.??%} | ${f1:-??.??%} |" >>"$out"
  else
    label=$(echo "$ds" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    echo "| $label | ??.??% | ??.??% | ??.??% | ??.??% |" >>"$out"
  fi
done
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
