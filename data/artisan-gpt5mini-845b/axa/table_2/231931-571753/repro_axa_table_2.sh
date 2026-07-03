#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table (unchanged)
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |         ?? / ??        |        ? / ?       |
| Interleaved Execution       |          ? / ?         |        ? / ?       |
| Mutual Recursion            |          ? / ?         |        ? / ?       |
| Unidirectional State Access |          ? / ?         |        ? / ?       |
| Bidirectional State Access  |          ? / ?         |        ? / ?       |
| **Sum**                     |       **?? / ??**      |     **?? / ??**    |

EOTABLE

# Section 2: Artifact download/load (idempotent)
artisan get https://zenodo.org/records/13374578 || true
# prefer loading provided image if present
if [ -f axa-artifact-image.tar ]; then
  docker load -i axa-artifact-image.tar || true
fi

# Section 3: Prepare container and run benchmarks
docker rm -f axa_container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name axa_container axaimage -c 'sleep infinity' >/dev/null 2>&1 || true

# Run JS benchmark and Native benchmark, capture outputs
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" > /workspace/js_output.txt 2>&1 || true
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" > /workspace/native_output.txt 2>&1 || true

# Section 4: Parse benchmark outputs to extract Passed/Total per category.
parse_field() {
  local pattern="$1"
  local file="$2"
  # Look for a table line containing the pattern and extract the middle column (Passed / Total)
  grep -E "^[[:space:]]*\\|[[:space:]]*${pattern}" "$file" -m 1 || true
}

extract_value() {
  # Given a matched table line, extract the third '|' column and trim whitespace
  local line="$1"
  if [ -z "$line" ]; then
    echo ""
    return
  fi
  echo "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Categories in the order expected by the table
categories=(
  "Unidirectional Execution"
  "Interleaved Execution"
  "Mutual Recursion"
  "Unidirectional State Access"
  "Bidirectional State Access"
)

# Build associative arrays for values
declare -A js_vals
declare -A native_vals

for cat in "${categories[@]}"; do
  js_line=$(parse_field "$cat" /workspace/js_output.txt)
  native_line=$(parse_field "$cat" /workspace/native_output.txt)
  js_vals["$cat"]="$(extract_value "$js_line")"
  native_vals["$cat"]="$(extract_value "$native_line")"
done

# If Overall line is present, parse overall values as the sum entries
js_overall_line=$(grep -E "^[[:space:]]*\\|[[:space:]]*Overall" /workspace/js_output.txt -m 1 || true)
native_overall_line=$(grep -E "^[[:space:]]*\\|[[:space:]]*Overall" /workspace/native_output.txt -m 1 || true)
js_overall="$(extract_value "$js_overall_line")"
native_overall="$(extract_value "$native_overall_line")"

# Fallback: if overall missing, compute sums
compute_sum() {
  local -n arr=$1
  local passed=0
  local total=0
  for key in "${!arr[@]}"; do
    val="${arr[$key]}"
    if [ -n "$val" ] && echo "$val" | grep -q '/'; then
      p=$(echo "$val" | awk -F'/' '{print $1}' | tr -d '[:space:]')
      t=$(echo "$val" | awk -F'/' '{print $2}' | tr -d '[:space:]')
      # only add numeric values
      if [[ "$p" =~ ^[0-9]+$ ]] && [[ "$t" =~ ^[0-9]+$ ]]; then
        passed=$((passed + p))
        total=$((total + t))
      fi
    fi
  done
  echo "${passed} / ${total}"
}

if [ -z "$js_overall" ]; then
  js_overall="$(compute_sum js_vals)"
fi
if [ -z "$native_overall" ]; then
  native_overall="$(compute_sum native_vals)"
fi

# Section 5: Write /workspace/repro.txt based on parsed values (no hard-coded numeric table)
{
  echo "**Table 2: Benchmark Results**"
  echo
  printf "| Category                    | Passed/Test JavaScript | Passed/Test Native |\n"
  printf "| --------------------------- | :--------------------: | :----------------: |\n"
  for cat in "${categories[@]}"; do
    js_v="${js_vals[$cat]}"
    native_v="${native_vals[$cat]}"
    # If any value is empty, show "n/a"
    [ -z "$js_v" ] && js_v="n/a"
    [ -z "$native_v" ] && native_v="n/a"
    printf "| %-27s | %8s / %2s         | %8s / %2s       |\n" "$cat" "$(echo $js_v | awk -F'/' '{print $1}' | tr -d ' ')" "$(echo $js_v | awk -F'/' '{print $2}' | tr -d ' ')" "$(echo $native_v | awk -F'/' '{print $1}' | tr -d ' ')" "$(echo $native_v | awk -F'/' '{print $2}' | tr -d ' ')"
  done
  # Sum row using parsed overall values
  # Normalize overall values to "passed / total"
  js_pass="$(echo "$js_overall" | awk -F'/' '{print $1}' | tr -d '[:space:]')"
  js_tot="$(echo "$js_overall" | awk -F'/' '{print $2}' | tr -d '[:space:]')"
  native_pass="$(echo "$native_overall" | awk -F'/' '{print $1}' | tr -d '[:space:]')"
  native_tot="$(echo "$native_overall" | awk -F'/' '{print $2}' | tr -d '[:space:]')"
  echo "| **Sum**                     |       **${js_pass} / ${js_tot}**      |     **${native_pass} / ${native_tot}**    |"
} > /workspace/repro.txt

# Section 6: Format and submit output for evaluation
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
