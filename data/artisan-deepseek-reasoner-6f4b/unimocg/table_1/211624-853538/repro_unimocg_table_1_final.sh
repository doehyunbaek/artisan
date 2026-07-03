#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Soundness of call-graphs for different JVM features**

| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |
| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |
| Non-virtual Calls    |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Virtual Calls        |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Types                |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Static Initializer   |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Java ? Interfaces    |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Unsafe               |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Class.forName        |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Sign. Polymorph.     |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Java ?+              |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Non-Java             |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| MethodHandle         |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Invokedynamic        |           ?/?? |          ??/?? |            ??/?? |          ??/?? |          ??/?? |            ??/?? |
| Reflection           |           ?/?? |           ?/?? |             ?/?? |           ?/?? |           ?/?? |             ?/?? |
| JVM Calls            |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Serialization        |           ?/?? |           ?/?? |             ?/?? |           ?/?? |           ?/?? |             ?/?? |
| Library Analysis     |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| Class Loading        |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| DynamicProxy         |            ?/? |            ?/? |              ?/? |            ?/? |            ?/? |              ?/? |
| **Sum (out of ???)** |   **?? (??%)** |   **?? (??%)** |     **?? (??%)** |   **?? (??%)** |   **?? (??%)** |     **?? (??%)** |

*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011
# Section 3: Reproduction commands (populate from reviewed steps)
# Parse the summary file and generate Table 1 with correct rounding
python3 <<'PYTHONEOF' > /workspace/repro.txt
import re
import math

summary_path = "Unimocg_Artifact/summaries/summary_results_fingerprint.txt"
with open(summary_path, 'r') as f:
    content = f.read()

# Split by algorithm sections
algo_data = {}
sections = re.split(r'=+\n', content)
for sec in sections:
    sec = sec.strip()
    if not sec:
        continue
    lines = sec.split('\n')
    header = lines[0].strip()
    if not header.endswith('.profile'):
        continue
    algo = header[:-8]
    algo_data[algo] = {}
    for line in lines[1:]:
        line = line.strip()
        if line.startswith('Sum'):
            # Sum (out of 123): 51 (41.46341463414634)
            m = re.search(r'Sum \(out of (\d+)\): (\d+) \(([\d.]+)\)', line)
            if m:
                total = int(m.group(1))
                passed = int(m.group(2))
                percent = float(m.group(3))
                algo_data[algo]['total'] = total
                algo_data[algo]['sum_passed'] = passed
                algo_data[algo]['sum_percent'] = percent
        elif ':' in line:
            k, v = line.split(':', 1)
            algo_data[algo][k.strip()] = v.strip()

# Mapping from summary feature to table feature
feature_map = {
    'Non-virtual Calls': 'Non-virtual Calls',
    'Virtual Calls': 'Virtual Calls',
    'Types': 'Types',
    'Static Initializer': 'Static Initializer',
    'Java 8 Interfaces': 'Java 8 Interfaces',
    'Unsafe': 'Unsafe',
    'Class.forName': 'Class.forName',
    'Signature Polymorphic Methods': 'Sign. Polymorph.',
    'Java 9+': 'Java 9+',
    'Non-Java': 'Non-Java',
    'MethodHandle': 'MethodHandle',
    'Invokedynamic': 'Invokedynamic',
    'Reflection': 'Reflection',
    'JVM Calls': 'JVM Calls',
    'Serialization': 'Serialization',
    'Library Analysis': 'Library Analysis',
    'Class Loading': 'Class Loading',
    'DynamicProxy': 'DynamicProxy',
}

# Algorithms for Table 1
algorithms = ['WALA-CHA', 'WALA-RTA', 'WALA-0-CFA', 'Soot-CHA', 'Soot-RTA', 'Soot-SPARK']

# Build rows
rows = []
for sum_feat, tab_feat in feature_map.items():
    row = [tab_feat]
    for algo in algorithms:
        val = algo_data.get(algo, {}).get(sum_feat, '?/?')
        row.append(val)
    rows.append(row)

# Sum row
sum_row = ['**Sum (out of 123)**']
for algo in algorithms:
    if algo in algo_data:
        passed = algo_data[algo]['sum_passed']
        percent = algo_data[algo]['sum_percent']
        # Round to nearest integer as in paper
        rounded_percent = round(percent)
        sum_row.append(f'**{passed} ({rounded_percent}%)**')
    else:
        sum_row.append('**?? (??%)**')

# Print table
print('**Table 1: Soundness of call-graphs for different JVM features**')
print()
print('| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |')
print('| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |')
for row in rows:
    feat = row[0]
    vals = row[1:]
    print(f'| {feat:<20} | {vals[0]:>12} | {vals[1]:>12} | {vals[2]:>14} | {vals[3]:>12} | {vals[4]:>12} | {vals[5]:>14} |')
print(f'| {sum_row[0]} | {sum_row[1]} | {sum_row[2]} | {sum_row[3]} | {sum_row[4]} | {sum_row[5]} | {sum_row[6]} |')
print()
print('*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*')
PYTHONEOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
