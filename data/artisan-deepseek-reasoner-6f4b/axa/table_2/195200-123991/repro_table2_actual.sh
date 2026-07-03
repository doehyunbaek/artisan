#!/usr/bin/bash
# Section 1: Expected table
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
# Section 2: Artifact download (skip if already present)
if [ ! -f axa-artifact.zip ]; then
    artisan get https://zenodo.org/records/13374578
fi
# Section 3: Reproduction commands
# Ensure Docker image is loaded
if ! docker image inspect axaimage:latest >/dev/null 2>&1; then
    docker load -i axa-artifact-image.tar
fi
# Use the existing container (id from earlier)
CONTAINER_ID=54e8e278a6d5
# Run JavaScript benchmark and capture output
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" > /workspace/js_bench.txt 2>&1 || true
# Run Native benchmark and capture output
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" > /workspace/native_bench.txt 2>&1
# Extract results from the captured output files
JS_UNI=$(grep -A 5 "Unidirectional Execution" /workspace/js_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_INT=$(grep -A 5 "Interleaved Execution" /workspace/js_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_REC=$(grep -A 5 "Mutual Recursion" /workspace/js_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_UNI_SA=$(grep -A 5 "Unidirectional State Access" /workspace/js_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_BI_SA=$(grep -A 5 "Bidirectional State Access" /workspace/js_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_SUM=$(grep -A 5 "Overall" /workspace/js_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_UNI=$(grep -A 5 "Unidirectional Execution" /workspace/native_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_INT=$(grep -A 5 "Interleaved Execution" /workspace/native_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_REC=$(grep -A 5 "Mutual Recursion" /workspace/native_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_UNI_SA=$(grep -A 5 "Unidirectional State Access" /workspace/native_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_BI_SA=$(grep -A 5 "Bidirectional State Access" /workspace/native_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_SUM=$(grep -A 5 "Overall" /workspace/native_bench.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
# Write reproduction table with extracted values
cat > /workspace/repro.txt <<EOREPRO
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |         $JS_UNI        |        $NAT_UNI    |
| Interleaved Execution       |         $JS_INT        |        $NAT_INT    |
| Mutual Recursion            |         $JS_REC        |        $NAT_REC    |
| Unidirectional State Access |         $JS_UNI_SA     |        $NAT_UNI_SA |
| Bidirectional State Access  |         $JS_BI_SA      |        $NAT_BI_SA  |
| **Sum**                     |       **$JS_SUM**      |     **$NAT_SUM**   |

EOREPRO
# Section 4: Formatting and submission
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
