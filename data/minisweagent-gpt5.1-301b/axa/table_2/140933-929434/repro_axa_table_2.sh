#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |         15 / 16        |        2 / 2       |
| Interleaved Execution       |          5 / 5         |        7 / 7       |
| Mutual Recursion            |          2 / 4         |        1 / 1       |
| Unidirectional State Access |          6 / 6         |        4 / 4       |
| Bidirectional State Access  |          7 / 9         |        2 / 2       |
| **Sum**                     |       **35 / 40**      |     **16 / 16**    |

EOTABLE

# Section 2: Artifact download
cd /workspace

# Download main artifact archive if needed
if [ ! -f axa-artifact.zip ]; then
  curl -L "https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1" -o axa-artifact.zip
fi

# Unpack artifact directory if needed
if [ ! -d axa-artifact ]; then
  unzip -d axa-artifact axa-artifact.zip
fi

# Download Docker image tarball if needed
if [ ! -f axa-artifact-image.tar ]; then
  curl -L "https://zenodo.org/records/13374578/files/axa-artifact-image.tar?download=1" -o axa-artifact-image.tar
fi

# Load Docker image
docker load -i axa-artifact-image.tar

# Section 3: Reproduction commands (populate from reviewed steps)

# Ensure a clean container instance
docker rm -f axa_table2 >/dev/null 2>&1 || true

# Start container in detached mode as per instructions
docker run -d --init --entrypoint bash --name axa_table2 axaimage -c 'sleep infinity' >/dev/null

# Run Java–JavaScript benchmarks for Table II; allow non-zero exit (some tests intentionally fail)
docker exec axa_table2 /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" > /workspace/run_js.log 2>&1 || true

# Run Java–Native benchmarks for Table II
docker exec axa_table2 /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" > /workspace/run_native.log 2>&1

cd /workspace

# Parse JavaScript benchmark results from LaTeX macros in the log
js_unidir=$(sed -n 's/\\newcommand{\\controlflowunidirectional}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)
js_interleaved=$(sed -n 's/\\newcommand{\\controlflowinterleaved}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)
js_cyclic=$(sed -n 's/\\newcommand{\\controlflowcyclic}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)
js_state_uni=$(sed -n 's/\\newcommand{\\stateaccessunidirectional}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)
js_state_bi=$(sed -n 's/\\newcommand{\\stateaccessbidirectional}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)
js_overall_tests=$(sed -n 's/\\newcommand{\\overalltests}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)
js_testcase_count=$(sed -n 's/\\newcommand{\\testcasecount}{\\tnum{\([^}]*\)}}/\1/p' run_js.log | head -n1)

# Parse Native benchmark results from LaTeX macros in the log
native_unidir=$(sed -n 's/\\newcommand{\\controlflowunidirectional}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)
native_interleaved=$(sed -n 's/\\newcommand{\\controlflowinterleaved}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)
native_cyclic=$(sed -n 's/\\newcommand{\\controlflowcyclic}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)
native_state_uni=$(sed -n 's/\\newcommand{\\stateaccessunidirectional}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)
native_state_bi=$(sed -n 's/\\newcommand{\\stateaccessbidirectional}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)
native_overall_tests=$(sed -n 's/\\newcommand{\\overalltests}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)
native_testcase_count=$(sed -n 's/\\newcommand{\\testcasecount}{\\tnum{\([^}]*\)}}/\1/p' run_native.log | head -n1)

# Compose the reproduced Table 2 into /workspace/repro.txt
cat > /workspace/repro.txt <<EOTABLE
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript         | Passed/Test Native               |
| --------------------------- | :----------------------------: | :------------------------------: |
| Unidirectional Execution    | ${js_unidir}                   | ${native_unidir}                 |
| Interleaved Execution       | ${js_interleaved}              | ${native_interleaved}            |
| Mutual Recursion            | ${js_cyclic}                   | ${native_cyclic}                 |
| Unidirectional State Access | ${js_state_uni}                | ${native_state_uni}              |
| Bidirectional State Access  | ${js_state_bi}                 | ${native_state_bi}               |
| **Sum**                     | **${js_overall_tests} / ${js_testcase_count}** | **${native_overall_tests} / ${native_testcase_count}** |

EOTABLE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
