#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | ??.?? | ????.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | -??.?? | ????.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
# Run the analysis using the provided helper script (which uses the Docker image as per README).
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts || { echo "artifact dir not found"; exit 1; }
# Ensure the run-analysis.sh is executable, then run it (this will pull and run the Docker image mdipenta/rexp and produce results/)
chmod +x run-analysis.sh || true
sh run-analysis.sh
# Try to locate files containing Table 6 in the produced results and write them to /workspace/repro.txt
(
  echo "=== Files containing literal 'Table 6' (if any) ==="
  grep -R --line-number -i "Table 6" results || true
  echo
  echo "=== Candidate files (by name) and their first 200 lines ==="
  find results -type f \( -iname "*table*6*" -o -iname "*table_6*" -o -iname "*6*.csv" -o -iname "*6*.tex" \) -print -exec echo "---- {} ----" \; -exec sed -n '1,200p' {} \;
  echo
  echo "=== All CSV files under results/tables or results that might match Tables 2-9 ==="
  find results -type f -iname "*.csv" -print -exec echo "---- {} ----" \; -exec sed -n '1,200p' {} \;
) > /workspace/repro.txt 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
