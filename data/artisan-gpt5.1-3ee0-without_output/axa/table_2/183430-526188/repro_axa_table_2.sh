#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |        15 / 16         |      2 / 2         |
| Interleaved Execution       |         5 / 5          |      7 / 7         |
| Mutual Recursion            |         2 / 4          |      1 / 1         |
| Unidirectional State Access |         6 / 6          |      4 / 4         |
| Bidirectional State Access  |         7 / 9          |      2 / 2         |
| **Sum**                     |      **35 / 40**       |    **16 / 16**     |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578

# Section 3: Reproduction commands
# Load the prebuilt Docker image and start a container
docker load -i axa-artifact-image.tar
docker rm -f axa-container 2>/dev/null || true
docker run -d --init --entrypoint bash --name axa-container axaimage -c 'sleep infinity'

# Run the benchmarks inside the container, capturing logs
docker exec axa-container /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh > /runner/js_benchmark.log 2>&1" || true
docker exec axa-container /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh > /runner/native_benchmark.log 2>&1" || true

# Parse JavaScript benchmark results from the log
js_unidir=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/js_benchmark.log' | awk -F"|" '/Unidirectional Execution/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
js_interleaved=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/js_benchmark.log' | awk -F"|" '/Interleaved Execution/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
js_mutual=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/js_benchmark.log' | awk -F"|" '/Mutual Recursion/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
js_stateuni=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/js_benchmark.log' | awk -F"|" '/Unidirectional State Access/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
js_statebi=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/js_benchmark.log' | awk -F"|" '/Bidirectional State Access/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
js_overall=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/js_benchmark.log' | awk -F"|" '/Overall/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')

# Parse Native benchmark results from the log
native_unidir=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/native_benchmark.log' | awk -F"|" '/Unidirectional Execution/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
native_interleaved=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/native_benchmark.log' | awk -F"|" '/Interleaved Execution/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
native_mutual=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/native_benchmark.log' | awk -F"|" '/Mutual Recursion/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
native_stateuni=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/native_benchmark.log' | awk -F"|" '/Unidirectional State Access/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
native_statebi=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/native_benchmark.log' | awk -F"|" '/Bidirectional State Access/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')
native_overall=$(docker exec axa-container /bin/bash --noprofile --norc -c 'tail -n 80 /runner/native_benchmark.log' | awk -F"|" '/Overall/ {gsub(/^[ \t]+/,"",$3); gsub(/[ \t]+$/,"",$3); print $3}')

# Write the reproduced table using the parsed values
cat > /workspace/repro.txt <<EOREPRO
**Table 2: Benchmark Results (Reproduction)**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |        ${js_unidir}        |      ${native_unidir}         |
| Interleaved Execution       |         ${js_interleaved}          |      ${native_interleaved}         |
| Mutual Recursion            |         ${js_mutual}          |      ${native_mutual}          |
| Unidirectional State Access |         ${js_stateuni}          |      ${native_stateuni}          |
| Bidirectional State Access  |         ${js_statebi}          |      ${native_statebi}          |
| **Sum**                     |      **${js_overall}**       |    **${native_overall}**     |

EOREPRO

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
