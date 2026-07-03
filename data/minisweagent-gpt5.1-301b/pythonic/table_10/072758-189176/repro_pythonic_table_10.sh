#!/usr/bin/bash
set -e

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 10: Reasons for using functional and procedural code**

| Reason                        | Lambdas | Comp. | MRF | Proc. |
| ----------------------------- | ------: | ----: | --: | ----: |
| Coding time                   |      11 |    12 |  10 |     2 |
| Ease of use                   |       4 |    10 |   8 |     7 |
| Maintainability               |      14 |     9 |  14 |     6 |
| Performance                   |       7 |    28 |  23 |     6 |
| Readability/Understandability |      19 |    89 |  33 |    27 |
| Size                          |      41 |    76 |  39 |     — |
| Lack of knowledge             |       — |     — |   — |    16 |
| Project constraints           |       — |     — |   — |     5 |
| Simplify debugging            |       — |     — |   — |     9 |

EOTABLE

# Section 2: Artifact download
BASE="/workspace"
ART_ZIP="$BASE/ICSE2024-funcConstructs-Artifacts.zip"
ART_DIR="$BASE/ICSE2024-funcConstructs-Artifacts"
ART_INNER="$ART_DIR/ICSE2024-funcConstructs-Artifacts"

mkdir -p "$BASE"

if [ ! -f "$ART_ZIP" ]; then
  curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1" -o "$ART_ZIP"
fi

if [ ! -d "$ART_INNER" ]; then
  mkdir -p "$ART_DIR"
  unzip -d "$ART_DIR" "$ART_ZIP"
fi

# Section 3: Reproduction commands (populate from reviewed steps)
XLS="$ART_INNER/working-results/RQ3ManualValidation.xlsx"

sheet_stream() {
  local SHEET="$1"
  if [ "$SHEET" = "Procedural" ]; then
    uvx --from csvkit in2csv "$XLS" --sheet "$SHEET" \
      | uvx --from csvkit csvcut -c "Final Classification" \
      | tail -n +2 \
      | sed 's/^ *//;s/ *$//' \
      | sed 's/^Debugging is easier$/Simplify debugging/;s/^Project [Cc]onstraint$/Project constraints/;s/^lack of knowledge$/Lack of knowledge/'
  else
    uvx --from csvkit in2csv "$XLS" --sheet "$SHEET" \
      | uvx --from csvkit csvcut -c "Final Classification" \
      | tail -n +2 \
      | sed 's/^ *//;s/ *$//'
  fi
}

display_cell() {
  local v="$1"
  if [ "$v" -eq 0 ] 2>/dev/null; then
    printf "—"
  else
    printf "%s" "$v"
  fi
}

# Lambda counts
LAMBDA_CODING=$(sheet_stream "Lambda" | grep -x "Coding time" | wc -l)
LAMBDA_EASE=$(sheet_stream "Lambda" | grep -x "Ease of use" | wc -l)
LAMBDA_MAINT=$(sheet_stream "Lambda" | grep -x "Maintainability" | wc -l)
LAMBDA_PERF=$(sheet_stream "Lambda" | grep -x "Performance" | wc -l)
LAMBDA_READ=$(sheet_stream "Lambda" | grep -x "Readability/Understandability" | wc -l)
LAMBDA_SIZE=$(sheet_stream "Lambda" | grep -x "Size" | wc -l)
LAMBDA_LACK=$(sheet_stream "Lambda" | grep -x "Lack of knowledge" | wc -l)
LAMBDA_PROJ=$(sheet_stream "Lambda" | grep -x "Project constraints" | wc -l)
LAMBDA_DEBUG=$(sheet_stream "Lambda" | grep -x "Simplify debugging" | wc -l)

# Comprehension counts
COMP_CODING=$(sheet_stream "Comprehension" | grep -x "Coding time" | wc -l)
COMP_EASE=$(sheet_stream "Comprehension" | grep -x "Ease of use" | wc -l)
COMP_MAINT=$(sheet_stream "Comprehension" | grep -x "Maintainability" | wc -l)
COMP_PERF=$(sheet_stream "Comprehension" | grep -x "Performance" | wc -l)
COMP_READ=$(sheet_stream "Comprehension" | grep -x "Readability/Understandability" | wc -l)
COMP_SIZE=$(sheet_stream "Comprehension" | grep -x "Size" | wc -l)
COMP_LACK=$(sheet_stream "Comprehension" | grep -x "Lack of knowledge" | wc -l)
COMP_PROJ=$(sheet_stream "Comprehension" | grep -x "Project constraints" | wc -l)
COMP_DEBUG=$(sheet_stream "Comprehension" | grep -x "Simplify debugging" | wc -l)

# MRF counts
MRF_CODING=$(sheet_stream "MRF" | grep -x "Coding time" | wc -l)
MRF_EASE=$(sheet_stream "MRF" | grep -x "Ease of use" | wc -l)
MRF_MAINT=$(sheet_stream "MRF" | grep -x "Maintainability" | wc -l)
MRF_PERF=$(sheet_stream "MRF" | grep -x "Performance" | wc -l)
MRF_READ=$(sheet_stream "MRF" | grep -x "Readability/Understandability" | wc -l)
MRF_SIZE=$(sheet_stream "MRF" | grep -x "Size" | wc -l)
MRF_LACK=$(sheet_stream "MRF" | grep -x "Lack of knowledge" | wc -l)
MRF_PROJ=$(sheet_stream "MRF" | grep -x "Project constraints" | wc -l)
MRF_DEBUG=$(sheet_stream "MRF" | grep -x "Simplify debugging" | wc -l)

# Procedural counts
PROC_CODING=$(sheet_stream "Procedural" | grep -x "Coding time" | wc -l)
PROC_EASE=$(sheet_stream "Procedural" | grep -x "Ease of use" | wc -l)
PROC_MAINT=$(sheet_stream "Procedural" | grep -x "Maintainability" | wc -l)
PROC_PERF=$(sheet_stream "Procedural" | grep -x "Performance" | wc -l)
PROC_READ=$(sheet_stream "Procedural" | grep -x "Readability/Understandability" | wc -l)
PROC_SIZE=$(sheet_stream "Procedural" | grep -x "Size" | wc -l)
PROC_LACK=$(sheet_stream "Procedural" | grep -x "Lack of knowledge" | wc -l)
PROC_PROJ=$(sheet_stream "Procedural" | grep -x "Project constraints" | wc -l)
PROC_DEBUG=$(sheet_stream "Procedural" | grep -x "Simplify debugging" | wc -l)

# Build reproduced table
{
  echo "**Table 10: Reasons for using functional and procedural code**"
  echo
  echo "| Reason                        | Lambdas | Comp. | MRF | Proc. |"
  echo "| ----------------------------- | ------: | ----: | --: | ----: |"
  printf "| Coding time                   | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_CODING")" \
    "$(display_cell "$COMP_CODING")" \
    "$(display_cell "$MRF_CODING")" \
    "$(display_cell "$PROC_CODING")"
  printf "| Ease of use                   | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_EASE")" \
    "$(display_cell "$COMP_EASE")" \
    "$(display_cell "$MRF_EASE")" \
    "$(display_cell "$PROC_EASE")"
  printf "| Maintainability               | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_MAINT")" \
    "$(display_cell "$COMP_MAINT")" \
    "$(display_cell "$MRF_MAINT")" \
    "$(display_cell "$PROC_MAINT")"
  printf "| Performance                   | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_PERF")" \
    "$(display_cell "$COMP_PERF")" \
    "$(display_cell "$MRF_PERF")" \
    "$(display_cell "$PROC_PERF")"
  printf "| Readability/Understandability | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_READ")" \
    "$(display_cell "$COMP_READ")" \
    "$(display_cell "$MRF_READ")" \
    "$(display_cell "$PROC_READ")"
  printf "| Size                          | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_SIZE")" \
    "$(display_cell "$COMP_SIZE")" \
    "$(display_cell "$MRF_SIZE")" \
    "$(display_cell "$PROC_SIZE")"
  printf "| Lack of knowledge             | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_LACK")" \
    "$(display_cell "$COMP_LACK")" \
    "$(display_cell "$MRF_LACK")" \
    "$(display_cell "$PROC_LACK")"
  printf "| Project constraints           | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_PROJ")" \
    "$(display_cell "$COMP_PROJ")" \
    "$(display_cell "$MRF_PROJ")" \
    "$(display_cell "$PROC_PROJ")"
  printf "| Simplify debugging            | %6s | %4s | %3s | %4s |\n" \
    "$(display_cell "$LAMBDA_DEBUG")" \
    "$(display_cell "$COMP_DEBUG")" \
    "$(display_cell "$MRF_DEBUG")" \
    "$(display_cell "$PROC_DEBUG")"
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
