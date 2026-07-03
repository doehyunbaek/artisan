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
if [ ! -d /workspace/Unimocg_Artifact ]; then
  mkdir -p /workspace
  cd /workspace
  if [ ! -f Unimocg_Artifact.zip ]; then
    curl -L https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip -o Unimocg_Artifact.zip
  fi
  rm -rf Unimocg_Artifact
  unzip -q Unimocg_Artifact.zip -d Unimocg_Artifact
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Aggregate the precomputed OPAL fingerprint profiles for the five algorithms into /workspace/repro.txt
python3 /workspace/Unimocg_Artifact/docker/runner/aggregate_fingerprints.py /workspace/Unimocg_Artifact/evaluation/fingerprints/OPAL-*.profile > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 - <<'PY' > /workspace/repro_table.md
import re

alg_order = ["CHA", "RTA", "XTA", "0-CFA", "1-1-CFA"]
feat_order = [
    ("Non-virtual Calls", "Non-virtual Calls"),
    ("Virtual Calls", "Virtual Calls"),
    ("Types", "Types"),
    ("Static Initializer", "Static Initializer"),
    ("Java 8 Interfaces", "Java 8 Interfaces"),
    ("Unsafe", "Unsafe"),
    ("Class.forName", "Class.forName"),
    ("Signature Polymorphic Methods", "Sign. Polymorph."),
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

data = {}
sum_val = {}
current_alg = None

with open("/workspace/repro.txt", "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")

        # Detect OPAL profile sections from full file paths
        m = re.search(r"OPAL-(.+)\.profile", line)
        if m:
            prof = m.group(1)
            current_alg = prof if prof in alg_order else None
            continue

        if not current_alg:
            continue

        # Collect feature rows
        m = re.match(r"^([A-Z][A-Za-z 0-9+.\-]*): ([0-9]+/[0-9]+)$", line)
        if m:
            feat = m.group(1).strip()
            val = m.group(2).strip()
            data[(feat, current_alg)] = val
            continue

        # Collect sum row
        m = re.match(r"^Sum \(out of 123\): ([0-9]+) \(([0-9.]+)\)", line)
        if m:
            total = m.group(1)
            pct = float(m.group(2))
            pct_r = round(pct)
            sum_val[current_alg] = f"{total} ({pct_r}%)"
            continue

lines = []
lines.append("**Table 2: Soundness of Unimocg’s call-graph algorithms**")
lines.append("")
lines.append("| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |")
lines.append("| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |")

for orig, label in feat_order:
    row = f"| {label:<20} |"
    for alg in alg_order:
        val = data.get((orig, alg), "")
        row += f" {val:>11} |"
    lines.append(row)

row = "| **Sum (out of 123)** |"
for alg in alg_order:
    val = sum_val.get(alg, "")
    row += f" **{val:>9}** |"
lines.append(row)
lines.append("")
lines.append("*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*")

print("\n".join(lines))
PY
cat /workspace/repro_table.md
echo '</artisan_submit>'
