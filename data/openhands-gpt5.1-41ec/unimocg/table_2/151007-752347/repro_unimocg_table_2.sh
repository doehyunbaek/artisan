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
cd /workspace
if [ ! -f Unimocg_Artifact.zip ]; then
  curl -L "https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip" -o Unimocg_Artifact.zip
fi
if [ ! -d evaluation ] || [ ! -d docker ]; then
  unzip -o -q Unimocg_Artifact.zip
fi
# Section 3: Reproduction commands (populate from reviewed steps)
# Recompute soundness aggregates for OPAL call-graph algorithms
python3 docker/runner/aggregate_fingerprints.py \
  evaluation/fingerprints/OPAL-CHA.profile \
  evaluation/fingerprints/OPAL-RTA.profile \
  evaluation/fingerprints/OPAL-XTA.profile \
  evaluation/fingerprints/OPAL-0-CFA.profile \
  evaluation/fingerprints/OPAL-1-1-CFA.profile \
  > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 - <<'PY'
import pathlib
import re

repro_path = pathlib.Path('/workspace/repro.txt')
text = repro_path.read_text()

blocks = [b for b in text.split('===================================================================') if b.strip()]
alg_map = {}

for block in blocks:
    lines = [l for l in block.splitlines() if l.strip()]
    if not lines:
        continue
    filename = lines[0].strip()
    m = re.search(r'OPAL-(.+?)\.profile', filename)
    if not m:
        continue
    alg_id = m.group(1)
    if alg_id == 'CHA':
        alg_name = 'CHA'
    elif alg_id == 'RTA':
        alg_name = 'RTA'
    elif alg_id == 'XTA':
        alg_name = 'XTA'
    elif alg_id == '0-CFA':
        alg_name = '0-CFA'
    elif alg_id == '1-1-CFA':
        alg_name = '1-1-CFA'
    else:
        continue
    features = {}
    for l in lines[1:]:
        if ':' in l and '/' in l:
            feat, vals = l.split(':', 1)
            feat = feat.strip()
            vals = vals.strip()
            if re.match(r'^[0-9]+/[0-9]+$', vals):
                features[feat] = vals
    total_line = next((l for l in lines if l.startswith('Sum (out of')), None)
    if total_line:
        m2 = re.search(r'Sum \(out of (\d+)\): (\d+) \(([^)]+)\)', total_line)
        if m2:
            total = m2.group(1)
            sound = m2.group(2)
            perc = float(m2.group(3))
            features['__sum__'] = (sound, total, perc)
    alg_map[alg_name] = features

ordered_features = [
    'Non-virtual Calls',
    'Virtual Calls',
    'Types',
    'Static Initializer',
    'Java 8 Interfaces',
    'Unsafe',
    'Class.forName',
    'Signature Polymorphic Methods',
    'Java 9+',
    'Non-Java',
    'MethodHandle',
    'Invokedynamic',
    'Reflection',
    'JVM Calls',
    'Serialization',
    'Library Analysis',
    'Class Loading',
    'DynamicProxy',
]

algs = ['CHA', 'RTA', 'XTA', '0-CFA', '1-1-CFA']

print('**Table 2: Soundness of Unimocg’s call-graph algorithms**\n')
print('| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |')
print('| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |')

for feat in ordered_features:
    row_vals = []
    for alg in algs:
        val = alg_map.get(alg, {}).get(feat, '0/0')
        row_vals.append(val)
    print(f"| {feat:<20} | {row_vals[0]:>11} | {row_vals[1]:>11} | {row_vals[2]:>11} | {row_vals[3]:>11} | {row_vals[4]:>12} |")

# Sum row
base_sum = alg_map['CHA']['__sum__']
_, total, _ = base_sum
sum_cells = {}
for alg in algs:
    sound, tot, perc = alg_map[alg]['__sum__']
    pct_rounded = round(perc)
    sum_cells[alg] = f"**{sound} ({pct_rounded}%)**"

print(f"| **Sum (out of {total})** | {sum_cells['CHA']:>11} | {sum_cells['RTA']:>11} | {sum_cells['XTA']:>11} | {sum_cells['0-CFA']:>11} | {sum_cells['1-1-CFA']:>12} |")
print('\n*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*')
PY
echo '</artisan_submit>'
