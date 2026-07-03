#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |        15 / 16         |       2 / 2        |
| Interleaved Execution       |         5 / 5          |       7 / 7        |
| Mutual Recursion            |         2 / 4          |       1 / 1        |
| Unidirectional State Access |         6 / 6          |       4 / 4        |
| Bidirectional State Access  |         7 / 9          |       2 / 2        |
| **Sum**                     |     **35 / 40**        |    **16 / 16**     |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578
# Section 3: Reproduction commands
docker load -i axa-artifact-image.tar
CID=$(docker run -d --init --entrypoint bash axaimage -c 'sleep infinity')
docker exec "$CID" /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" > /workspace/js_benchmark.log 2>&1 || true
docker exec "$CID" /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" > /workspace/native_benchmark.log 2>&1
js_log="/workspace/js_benchmark.log"
native_log="/workspace/native_benchmark.log"
extract_ratio() {
  local name="$1" log="$2"
  grep -m1 "\\newcommand{\\${name}}" "$log" | sed -E 's/.*\\tnum\{([^}]*)\}.*/\1/'
}
JS_UNI=$(extract_ratio "controlflowunidirectional" "$js_log")
JS_INTER=$(extract_ratio "controlflowinterleaved" "$js_log")
JS_MUT=$(extract_ratio "controlflowcyclic" "$js_log")
JS_STATE_UNI=$(extract_ratio "stateaccessunidirectional" "$js_log")
JS_STATE_BI=$(extract_ratio "stateaccessbidirectional" "$js_log")
JS_OVERALL_PASSED=$(extract_ratio "overalltests" "$js_log")
JS_OVERALL_TOTAL=$(extract_ratio "testcasecount" "$js_log")
JS_SUM="${JS_OVERALL_PASSED} / ${JS_OVERALL_TOTAL}"
N_UNI=$(extract_ratio "controlflowunidirectional" "$native_log")
N_INTER=$(extract_ratio "controlflowinterleaved" "$native_log")
N_MUT=$(extract_ratio "controlflowcyclic" "$native_log")
N_STATE_UNI=$(extract_ratio "stateaccessunidirectional" "$native_log")
N_STATE_BI=$(extract_ratio "stateaccessbidirectional" "$native_log")
N_OVERALL_PASSED=$(extract_ratio "overalltests" "$native_log")
N_OVERALL_TOTAL=$(extract_ratio "testcasecount" "$native_log")
N_SUM="${N_OVERALL_PASSED} / ${N_OVERALL_TOTAL}"
cat > /workspace/repro.txt <<EOT
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |      ${JS_UNI}         |     ${N_UNI}       |
| Interleaved Execution       |      ${JS_INTER}       |     ${N_INTER}     |
| Mutual Recursion            |      ${JS_MUT}         |     ${N_MUT}       |
| Unidirectional State Access |      ${JS_STATE_UNI}   |     ${N_STATE_UNI} |
| Bidirectional State Access  |      ${JS_STATE_BI}    |     ${N_STATE_BI}  |
| **Sum**                     |   **${JS_SUM}**        |   **${N_SUM}**     |
EOT
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
