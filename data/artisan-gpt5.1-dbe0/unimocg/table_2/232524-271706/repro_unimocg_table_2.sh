#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Virtual Calls        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Types                |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Static Initializer   |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java 8 Interfaces    |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Unsafe               |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class.forName        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Sign. Polymorph.     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Java 9+              |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Non-Java             |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| MethodHandle         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Invokedynamic        |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| Reflection           |        ??/?? |        ??/?? |        ??/?? |        ??/?? |         ??/?? |
| JVM Calls            |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Serialization        |         ?/?? |         ?/?? |         ?/?? |         ?/?? |          ?/?? |
| Library Analysis     |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| Class Loading        |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| DynamicProxy         |          ?/? |          ?/? |          ?/? |          ?/? |           ?/? |
| **Sum (out of 123)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **?? (??%)** | **??? (??%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011

# Section 3: Reproduction commands – patch Dockerfile, build image, recompute fingerprints
cd /workspace/Unimocg_Artifact

# Reduce memory usage settings in runner scripts to fit the environment.
sed -i 's/-J-Xmx400G/-J-Xmx8G/g' docker/runner/createFingerprint.sh docker/runner/createFingerprintsAll.sh docker/runner/runJCG.sh docker/runner/runJCGAll.sh

# Patch Dockerfile:
#  - Fix OPAL Callees import package for the JCG OPAL adapter.
#  - Update cp of testcases to use the new "testcasesOutput" directory.
#  - Make the second cp tolerant if the directory is absent.
python3 - <<'PY'
from pathlib import Path

p = Path('docker/Dockerfile')
s = p.read_text()

marker = 'sbt compile && \\'
if marker not in s:
    raise SystemExit("Expected 'sbt compile && \\' not found in docker/Dockerfile")
replacement = (
    "sed -i 's/org.opalj.tac.fpcf.properties.cg/org.opalj.br.fpcf.properties.cg/g' "
    "jcg_opal_testadapter/src/main/scala/OpalJCGAdatper.scala && \\\n"
    "    sbt compile && \\"
)
s = s.replace(marker, replacement)

s = s.replace(
    "RUN cp -r /JCG/JCG/testcaseJars/* /evaluation/testcases",
    "RUN cp -r /JCG/JCG/testcasesOutput/* /evaluation/testcases"
)

s = s.replace(
    "RUN cp -r /JCG/JCG/infrastructure_incompatible_testcases/compiled_jars_and_configs/* /evaluation/testcases",
    "RUN cp -r /JCG/JCG/infrastructure_incompatible_testcases/compiled_jars_and_configs/* /evaluation/testcases || true"
)

p.write_text(s)
PY

# Build the Docker image (patched) using the helper script.
chmod +x createContainer.sh
./createContainer.sh

# Start the container in detached mode with a long-lived shell.
CID=$(docker run -d --init --entrypoint bash unimocgimage -c 'sleep infinity')

# Recompute fingerprints for the five OPAL algorithms used in Table 2.
for algo in CHA RTA XTA 0-CFA 1-1-CFA; do
  docker exec "$CID" /bin/bash --noprofile --norc -c "cd /JCG/JCG && /runner/createFingerprint.sh OPAL '$algo'"
done

# Aggregate only the freshly generated OPAL fingerprints to obtain per-category results.
docker exec "$CID" /bin/bash --noprofile --norc -c "\
python3 /runner/aggregate_fingerprints.py \
/evaluation/fingerprints/OPAL-CHA.profile \
/evaluation/fingerprints/OPAL-RTA.profile \
/evaluation/fingerprints/OPAL-XTA.profile \
/evaluation/fingerprints/OPAL-0-CFA.profile \
/evaluation/fingerprints/OPAL-1-1-CFA.profile" > /workspace/aggregate_results.txt

# Stop the container (image kept for provenance).
docker stop "$CID" >/dev/null

# Parse the aggregation output to construct Table 2 programmatically.
cat > /tmp/gen_table2_from_agg.py <<'PY'
import re
from pathlib import Path

text = Path('/workspace/aggregate_results.txt').read_text()

algos = {
    'CHA': 'OPAL-CHA.profile',
    'RTA': 'OPAL-RTA.profile',
    'XTA': 'OPAL-XTA.profile',
    '0-CFA': 'OPAL-0-CFA.profile',
    '1-1-CFA': 'OPAL-1-1-CFA.profile',
}

features = [
    ('Non-virtual Calls', 'Non-virtual Calls'),
    ('Virtual Calls', 'Virtual Calls'),
    ('Types', 'Types'),
    ('Static Initializer', 'Static Initializer'),
    ('Java 8 Interfaces', 'Java 8 Interfaces'),
    ('Unsafe', 'Unsafe'),
    ('Class.forName', 'Class.forName'),
    ('Sign. Polymorph.', 'Signature Polymorphic Methods'),
    ('Java 9+', r'Java 9\+'),
    ('Non-Java', 'Non-Java'),
    ('MethodHandle', 'MethodHandle'),
    ('Invokedynamic', 'Invokedynamic'),
    ('Reflection', 'Reflection'),
    ('JVM Calls', 'JVM Calls'),
    ('Serialization', 'Serialization'),
    ('Library Analysis', 'Library Analysis'),
    ('Class Loading', 'Class Loading'),
    ('DynamicProxy', 'DynamicProxy'),
]

results = {feat_label: {} for feat_label, _ in features}
sums = {}

for algo_label, profname in algos.items():
    pattern = rf"^=+\s*\n{re.escape(profname)}\s*\n\n(.*?^Sum \(out of 123\): (\d+) \(([\d.]+)\).*$)"
    m = re.search(pattern, text, flags=re.M | re.S)
    if not m:
        raise SystemExit(f"Profile block for {profname} not found in aggregate output")
    block = m.group(1)
    total = int(m.group(2))
    pct = float(m.group(3))
    sums[algo_label] = (total, pct)
    for feat_label, src_pat in features:
        m2 = re.search(rf"^{src_pat}: (\d+/\d+)$", block, flags=re.M)
        if not m2:
            raise SystemExit(f"Feature {src_pat} not found in {profname}")
        results[feat_label][algo_label] = m2.group(1)

def fmt_pct(x: float) -> str:
    return f"{x:.2f}%"

print("**Table 2: Soundness of Unimocg’s call-graph algorithms**")
print()
print("| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |")
print("| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |")
for feat_label, _ in features:
    row = [feat_label]
    for algo_label in ['CHA', 'RTA', 'XTA', '0-CFA', '1-1-CFA']:
        row.append(results[feat_label][algo_label])
    print("| {0:20} | {1:11} | {2:11} | {3:11} | {4:11} | {5:12} |".format(*row))

sum_cells = []
for algo_label in ['CHA', 'RTA', 'XTA', '0-CFA', '1-1-CFA']:
    total, pct = sums[algo_label]
    sum_cells.append(f"**{total} ({fmt_pct(pct)})**")

print("| **Sum (out of 123)** | {0:11} | {1:11} | {2:11} | {3:11} | {4:12} |".format(*sum_cells))
print()
print("*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*")
PY

python3 /tmp/gen_table2_from_agg.py > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
