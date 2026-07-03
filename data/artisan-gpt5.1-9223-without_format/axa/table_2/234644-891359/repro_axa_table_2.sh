#!/usr/bin/bash
set -e

# Section 1: Expected table (from paper)
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |        15 / 16         |       2 / 2        |
| Interleaved Execution       |         5 / 5          |       7 / 7        |
| Mutual Recursion            |         2 / 4          |       1 / 1        |
| Unidirectional State Access |         6 / 6          |       4 / 4        |
| Bidirectional State Access  |         7 / 9          |       2 / 2        |
| **Sum**                     |      **35 / 40**       |    **16 / 16**     |

EOTABLE

# Section 2: Artifact download (quieted to avoid large stdout)
artisan get https://zenodo.org/records/13374578 > /workspace/artifact_download.log 2>&1

# Section 3: Reproduction commands

# Load Docker image and start container
docker load -i axa-artifact-image.tar
docker rm -f axa_container 2>/dev/null || true
docker run -d --init --entrypoint bash --name axa_container axaimage -c 'sleep infinity'

# Run JS benchmark (may exit non‑zero because some tests are expected to fail)
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh > /runner/runJSBenchmark.log 2>&1" || true

# Run Native benchmark (expected to succeed)
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh > /runner/runNativeBenchmark.log 2>&1"

# Copy logs out of the container
docker exec axa_container /bin/bash --noprofile --norc -c "cat /runner/runJSBenchmark.log" > /workspace/runJSBenchmark.log
docker exec axa_container /bin/bash --noprofile --norc -c "cat /runner/runNativeBenchmark.log" > /workspace/runNativeBenchmark.log

JS_LOG=/workspace/runJSBenchmark.log
NATIVE_LOG=/workspace/runNativeBenchmark.log

# Helper to extract "Passed / Total" from a table row in a log
extract_metric() {
  local log="$1"
  local label="$2"
  # Find the row with the given label and trim the value column
  grep "| ${label}" "$log" | head -n 1 | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}'
}

# Extract JS metrics
js_uni=$(extract_metric "$JS_LOG" "Unidirectional Execution")
js_inter=$(extract_metric "$JS_LOG" "Interleaved Execution")
js_mutual=$(extract_metric "$JS_LOG" "Mutual Recursion")
js_state_uni=$(extract_metric "$JS_LOG" "Unidirectional State Access")
js_state_bi=$(extract_metric "$JS_LOG" "Bidirectional State Access")
js_overall=$(extract_metric "$JS_LOG" "Overall")

# Extract Native metrics
native_uni=$(extract_metric "$NATIVE_LOG" "Unidirectional Execution")
native_inter=$(extract_metric "$NATIVE_LOG" "Interleaved Execution")
native_mutual=$(extract_metric "$NATIVE_LOG" "Mutual Recursion")
native_state_uni=$(extract_metric "$NATIVE_LOG" "Unidirectional State Access")
native_state_bi=$(extract_metric "$NATIVE_LOG" "Bidirectional State Access")
native_overall=$(extract_metric "$NATIVE_LOG" "Overall")

# Section 3b: Build reproduced table from parsed metrics
cat > /workspace/repro.txt <<EOT
**Reproduced Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |        ${js_uni}       |      ${native_uni}      |
| Interleaved Execution       |        ${js_inter}       |      ${native_inter}      |
| Mutual Recursion            |        ${js_mutual}       |      ${native_mutual}      |
| Unidirectional State Access |        ${js_state_uni}       |      ${native_state_uni}      |
| Bidirectional State Access  |        ${js_state_bi}       |      ${native_state_bi}      |
| **Sum**                     |     **${js_overall}**     |   **${native_overall}**   |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
