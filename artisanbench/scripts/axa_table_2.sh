#!/usr/bin/bash
LOG=/workspace/repro.log
TABLE=/workspace/repro.txt

curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o axa-artifact-image.tar https://zenodo.org/api/records/13374578/files/axa-artifact-image.tar/content > "$LOG" 2>&1
docker load -i axa-artifact-image.tar >> "$LOG" 2>&1
docker rm -f axa_container 2>/dev/null >> "$LOG" 2>&1 || true
docker run -d --init --entrypoint bash --name axa_container axaimage -c 'sleep infinity' >> "$LOG" 2>&1
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh | tail -n 200" > /workspace/runJSBenchmark.log 2>&1
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh | tail -n 200" > /workspace/runNativeBenchmark.log 2>&1

JS_LOG=/workspace/runJSBenchmark.log
NATIVE_LOG=/workspace/runNativeBenchmark.log

extract_metric() {
  local log="$1"
  local label="$2"
  grep "| ${label}" "$log" | head -n 1 | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}'
}

js_uni=$(extract_metric "$JS_LOG" "Unidirectional Execution")
js_inter=$(extract_metric "$JS_LOG" "Interleaved Execution")
js_mutual=$(extract_metric "$JS_LOG" "Mutual Recursion")
js_state_uni=$(extract_metric "$JS_LOG" "Unidirectional State Access")
js_state_bi=$(extract_metric "$JS_LOG" "Bidirectional State Access")
js_overall=$(extract_metric "$JS_LOG" "Overall")

native_uni=$(extract_metric "$NATIVE_LOG" "Unidirectional Execution")
native_inter=$(extract_metric "$NATIVE_LOG" "Interleaved Execution")
native_mutual=$(extract_metric "$NATIVE_LOG" "Mutual Recursion")
native_state_uni=$(extract_metric "$NATIVE_LOG" "Unidirectional State Access")
native_state_bi=$(extract_metric "$NATIVE_LOG" "Bidirectional State Access")
native_overall=$(extract_metric "$NATIVE_LOG" "Overall")

cat > "$TABLE" <<EOT
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |        ${js_uni}       |      ${native_uni}      |
| Interleaved Execution       |        ${js_inter}       |      ${native_inter}      |
| Mutual Recursion            |        ${js_mutual}       |      ${native_mutual}      |
| Unidirectional State Access |        ${js_state_uni}       |      ${native_state_uni}      |
| Bidirectional State Access  |        ${js_state_bi}       |      ${native_state_bi}      |
| **Sum**                     |     **${js_overall}**     |   **${native_overall}**   |
EOT

echo '<artisan_submit>'
cat "$TABLE"
echo '</artisan_submit>'
