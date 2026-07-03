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
# Load Docker image if not already loaded
if ! docker image inspect axaimage:latest > /dev/null 2>&1; then
    docker load -i axa-artifact-image.tar
fi
# Start a new container (remove any existing with the same name to avoid conflicts)
docker rm -f axa-benchmark-container 2>/dev/null || true
CONTAINER_ID=$(docker run -d --init --name axa-benchmark-container --entrypoint bash axaimage:latest -c 'sleep infinity')
sleep 10
# Run JavaScript benchmark, ignore exit code as some tests may fail
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" > /workspace/js_benchmark_output.txt 2>&1 || true
# Run Native benchmark
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" > /workspace/native_benchmark_output.txt 2>&1
# Extract results from output files
# JavaScript results
JS_UNI=$(grep -A 5 "Unidirectional Execution" /workspace/js_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_INT=$(grep -A 5 "Interleaved Execution" /workspace/js_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_REC=$(grep -A 5 "Mutual Recursion" /workspace/js_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_UNI_SA=$(grep -A 5 "Unidirectional State Access" /workspace/js_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_BI_SA=$(grep -A 5 "Bidirectional State Access" /workspace/js_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
JS_SUM=$(grep -A 5 "Overall" /workspace/js_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
# Native results
NAT_UNI=$(grep -A 5 "Unidirectional Execution" /workspace/native_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_INT=$(grep -A 5 "Interleaved Execution" /workspace/native_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_REC=$(grep -A 5 "Mutual Recursion" /workspace/native_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_UNI_SA=$(grep -A 5 "Unidirectional State Access" /workspace/native_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_BI_SA=$(grep -A 5 "Bidirectional State Access" /workspace/native_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
NAT_SUM=$(grep -A 5 "Overall" /workspace/native_benchmark_output.txt | grep -o "[0-9]\+ / [0-9]\+" | head -1)
# Write reproduction table
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
# Clean up container
docker rm -f axa-benchmark-container 2>/dev/null || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
