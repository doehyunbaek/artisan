#!/usr/bin/bash
cd /workspace
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
if [ ! -d /workspace/axa-artifact ]; then
  curl -L 'https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1' -o axa-artifact.zip
  unzip -q axa-artifact.zip -d axa-artifact
fi
if ! docker image inspect axaimage:latest >/dev/null 2>&1; then
  curl -L 'https://zenodo.org/records/13374578/files/axa-artifact-image.tar?download=1' -o axa-artifact-image.tar
  docker load -i axa-artifact-image.tar
fi
# Section 3: Reproduction commands (populate from reviewed steps)
# They should output the reproduction results to /workspace/repro.txt
# Start a fresh container for the benchmarks
docker rm -f axa_table2_container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name axa_table2_container axaimage -c 'sleep infinity'
# Run JavaScript and native benchmarks inside the container, capturing logs
docker exec axa_table2_container /bin/bash --noprofile --norc -c '/runner/runJSBenchmark.sh' > /workspace/js_benchmark.log 2>&1 || true
docker exec axa_table2_container /bin/bash --noprofile --norc -c '/runner/runNativeBenchmark.sh' > /workspace/native_benchmark.log 2>&1
# Stop and remove the container after benchmarks
docker rm -f axa_table2_container >/dev/null 2>&1 || true
# Parse benchmark logs and build the reproduced Table 2 in /workspace/repro.txt
python - <<'PY'
from pathlib import Path

categories = [
    "Unidirectional Execution",
    "Interleaved Execution",
    "Mutual Recursion",
    "Unidirectional State Access",
    "Bidirectional State Access",
]

def extract_counts(path):
    text = Path(path).read_text(errors="replace")
    result = {}
    for line in text.splitlines():
        line = line.rstrip()
        if not line.startswith("|"):
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) != 2:
            continue
        name, counts = parts
        if name in categories and " / " in counts:
            result[name] = counts
    return [result.get(cat, "") for cat in categories]

js_counts = extract_counts("/workspace/js_benchmark.log")
native_counts = extract_counts("/workspace/native_benchmark.log")


def extract_overall(path):
    text = Path(path).read_text(errors="replace")
    for line in text.splitlines():
        line = line.rstrip()
        if line.startswith("| Overall"):
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) == 2:
                return parts[1]
    return ""

overall_js = extract_overall("/workspace/js_benchmark.log")
overall_native = extract_overall("/workspace/native_benchmark.log")

lines = []
lines.append("**Table 2: Benchmark Results**")
lines.append("")
lines.append("| Category | Passed/Test JavaScript | Passed/Test Native |")
lines.append("| -------- | --------------------- | ------------------ |")
for cat, j, n in zip(categories, js_counts, native_counts):
    lines.append(f"| {cat} | {j} | {n} |")
lines.append(f"| **Sum** | **{overall_js}** | **{overall_native}** |")

Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
