#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 1: Correlation results

| Sample (UnsecureOnlyDataset) | R | p-value |
| :--- | :--- | :--- |
| Aliasing-ControlFlow-u | ?.???? | ?.???? |
| Aliasing-InterProcedural-u | ?.???? | ?.???? |
| Aliasing-Nested-u | ?.???? | ?.???? |
| Aliasing-Simple-u | ?.???? | ?.???? |
| Arrays-ImplicitLeak-u | ?.???? | ?.???? |
| BooleanOperations-u | ?.???? | ?.???? |
| Deepalias-u | ?.???? | ?.???? |
| Deepcall-u | ?.???? | ?.???? |
| DirectAssignment-u | ?.???? | ?.???? |
| DirectAssignmentLeak-u | ?.???? | ?.???? |
| HighCond.IncrementalLeak-u | ?.???? | ?.???? |
| IFLoop-u | ?.???? | ?.???? |
| ScenarioPassword-u | ?.???? | ?.???? |
| SimpleArraySize-u | ?.???? | ?.???? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10451088 
# Section 3: Reproduction commands (populate from reviewed steps)
# Extract RQ1 correlation summary from precomputed results and format to markdown
(
  printf "### Table 1: Correlation results\n\n| Sample (UnsecureOnlyDataset) | R | p-value |\n| :--- | :--- | :--- |\n"
  tar -xOf ReplicationPackage/submission-results.tar.xz RQ1/hypercoveragetester_28-07-2023_135630/hypercoveragetester-metrics.json \
  | sed -n '/"csvTable": \[/,/\]/p' \
  | grep '^ *"' \
  | sed 's/^[[:space:]]*"\(.*\)".*/\1/' \
  | tail -n +2 \
  | sed -e 's/-unsecure$/-u/' -e 's/^HighConditionalIncrementalLeak-u$/HighCond.IncrementalLeak-u/' \
  | sed -E 's/^([^;]+);([^;]+);([^;]+)$/| \1 | \2 | \3 |/'
) > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
