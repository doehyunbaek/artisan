#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Soundness of Unimocg’s call-graph algorithms**

| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |
| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |
| Non-virtual Calls    |          6/6 |          6/6 |          6/6 |          6/6 |           6/6 |
| Virtual Calls        |          4/4 |          4/4 |          4/4 |          4/4 |           4/4 |
| Types                |          6/6 |          6/6 |          6/6 |          6/6 |           6/6 |
| Static Initializer   |          8/8 |          8/8 |          8/8 |          8/8 |           8/8 |
| Java 8 Interfaces    |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Unsafe               |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Class.forName        |          4/4 |          4/4 |          4/4 |          4/4 |           4/4 |
| Sign. Polymorph.     |          7/7 |          7/7 |          7/7 |          7/7 |           7/7 |
| Java 9+              |          2/2 |          2/2 |          2/2 |          2/2 |           2/2 |
| Non-Java             |          2/2 |          2/2 |          2/2 |          2/2 |           2/2 |
| MethodHandle         |          9/9 |          9/9 |          9/9 |          9/9 |           9/9 |
| Invokedynamic        |        11/16 |        11/16 |        11/16 |        11/16 |         11/16 |
| Reflection           |        10/16 |        10/16 |        10/16 |        10/16 |         13/16 |
| JVM Calls            |          3/5 |          3/5 |          3/5 |          3/5 |           3/5 |
| Serialization        |         9/14 |         9/14 |         9/14 |         9/14 |          9/14 |
| Library Analysis     |          2/5 |          2/5 |          2/5 |          2/5 |           2/5 |
| Class Loading        |          0/4 |          0/4 |          0/4 |          0/4 |           0/4 |
| DynamicProxy         |          0/1 |          0/1 |          0/1 |          0/1 |           0/1 |
| **Sum (out of 123)** | **97 (79%)** | **97 (79%)** | **97 (79%)** | **97 (79%)** | **100 (81%)** |

*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011
# Section 3: Reproduction commands (populate from reviewed steps)
python3 - <<'PY'
import subprocess, re, pathlib

# OPAL algorithms corresponding to the table columns
profiles = [
    ("CHA", "Unimocg_Artifact/evaluation/fingerprints/OPAL-CHA.profile"),
    ("RTA", "Unimocg_Artifact/evaluation/fingerprints/OPAL-RTA.profile"),
    ("XTA", "Unimocg_Artifact/evaluation/fingerprints/OPAL-XTA.profile"),
    ("0-CFA", "Unimocg_Artifact/evaluation/fingerprints/OPAL-0-CFA.profile"),
    ("1-1-CFA", "Unimocg_Artifact/evaluation/fingerprints/OPAL-1-1-CFA.profile"),
]

# Run the artifact's aggregation script on the raw fingerprint profiles
agg_script = "Unimocg_Artifact/docker/runner/aggregate_fingerprints.py"
cmd = ["python3", agg_script] + [p for (_, p) in profiles]
out = subprocess.check_output(cmd, text=True)

algs = [name for (name, _) in profiles]
data = {}
current = None
alg_index = -1

# Parse the aggregation output into a structured dict
for line in out.splitlines():
    line = line.rstrip("\n")
    if line.startswith("==================================================================="):
        alg_index += 1
        if alg_index >= len(algs):
            break
        current = algs[alg_index]
        data[current] = {}
    elif ":" in line and "/" in line and not line.startswith("Sum (out of"):
        key, rest = line.split(":", 1)
        data[current][key.strip()] = rest.strip()
    elif line.startswith("Sum (out of"):
        m = re.search(r"Sum \(out of (\d+)\): (\d+)", line)
        if m:
            total = int(m.group(1))
            passed = int(m.group(2))
            data[current]["__sum__"] = (passed, total)

# Row mapping: display name -> key used by the aggregation script
rows = [
    ("Non-virtual Calls", "Non-virtual Calls"),
    ("Virtual Calls", "Virtual Calls"),
    ("Types", "Types"),
    ("Static Initializer", "Static Initializer"),
    ("Java 8 Interfaces", "Java 8 Interfaces"),
    ("Unsafe", "Unsafe"),
    ("Class.forName", "Class.forName"),
    ("Sign. Polymorph.", "Signature Polymorphic Methods"),
    ("Java 9+", "Java 9+"),
    ("Non-Java", "Non-Java"),
    ("MethodHandle", "MethodHandle"),
    ("Invokedynamic", "Invokedynamic"),
    ("Reflection", "Reflection"),
    ("JVM Calls", "JVM Calls"),
    ("Serialization", "Serialization"),
    ("Library Analysis", "Library Analysis"),
    ("Class Loading", "Class Loading"),
    ("DynamicProxy", "DynamicProxy"),
]

# Use the total number of test cases from any algorithm (they should all match)
any_alg = next(iter(data))
total_tests = data[any_alg]["__sum__"][1]

lines = []
lines.append("**Table 2: Soundness of Unimocg’s call-graph algorithms**")
lines.append("")
lines.append("| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |")
lines.append("| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |")

# Per-category rows
for display, key in rows:
    row = f"| {display:<20} "
    for alg in algs:
        frac = data[alg][key]  # e.g., "6/6"
        row += f"| {frac:>11} "
    row += "|"
    lines.append(row)

# Sum row with rounded percentages
sum_row = f"| **Sum (out of {total_tests})** "
for alg in algs:
    passed, total_local = data[alg]["__sum__"]
    perc = round(100 * passed / total_local)
    cell = f"**{passed} ({perc}%)**"
    sum_row += f"| {cell:>11} "
sum_row += "|"
lines.append(sum_row)
lines.append("")
lines.append("*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*")

pathlib.Path("/workspace/repro.txt").write_text("\n".join(lines))
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
