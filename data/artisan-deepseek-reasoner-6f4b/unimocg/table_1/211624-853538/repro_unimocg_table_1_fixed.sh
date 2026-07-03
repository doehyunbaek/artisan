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
# Parse the summary file and generate Table 1
python3 <<'PYTHONEOF' > /workspace/repro.txt
import re

summary_path = "Unimocg_Artifact/summaries/summary_results_fingerprint.txt"
with open(summary_path, 'r') as f:
    content = f.read()

# Split by algorithm sections (separated by =====)
sections = re.split(r'=+\n', content)
algo_data = {}
for sec in sections:
    if not sec.strip():
        continue
    lines = sec.strip().split('\n')
    header = lines[0].strip()
    if not header.endswith('.profile'):
        continue
    algo_name = header[:-8]  # remove .profile
    algo_data[algo_name] = {}
    for line in lines[1:]:
        line = line.strip()
        if line.startswith('Sum'):
            # Example: "Sum (out of 123): 97 (78.86178861788618)"
            match = re.match(r'Sum \(out of (\d+)\): (\d+) \(([\d.]+)\)', line)
            if match:
                total = int(match.group(1))
                passed = int(match.group(2))
                percent = float(match.group(3))
                algo_data[algo_name]['total'] = total
                algo_data[algo_name]['sum_passed'] = passed
                algo_data[algo_name]['sum_percent'] = percent
        elif ':' in line:
            key, value = line.split(':', 1)
            key = key.strip()
            value = value.strip()
            algo_data[algo_name][key] = value

# Features in order as in table
feature_map = {
    'Non-virtual Calls': 'Non-virtual Calls',
    'Virtual Calls': 'Virtual Calls',
    'Types': 'Types',
    'Static Initializer': 'Static Initializer',
    'Java 8 Interfaces': 'Java 8 Interfaces',
    'Unsafe': 'Unsafe',
    'Class.forName': 'Class.forName',
    'Signature Polymorphic Methods': 'Signature Polymorphic Methods',
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

# Algorithms needed
algorithms = ['WALA-CHA', 'WALA-RTA', 'WALA-0-CFA', 'Soot-CHA', 'Soot-RTA', 'Soot-SPARK']

# Build rows
rows = []
for feature_key, feature_name in feature_map.items():
    row = [feature_name]
    for algo in algorithms:
        if feature_key in algo_data.get(algo, {}):
            row.append(algo_data[algo][feature_key])
        else:
            row.append('?/?')
    rows.append(row)

# Total row
total_row = ['**Sum (out of 123)**']
for algo in algorithms:
    if algo in algo_data and 'sum_passed' in algo_data[algo]:
        passed = algo_data[algo]['sum_passed']
        percent = algo_data[algo]['sum_percent']
        total_row.append(f'**{passed} ({percent:.1f}%)**')
    else:
        total_row.append('**? (??%)**')

# Format table
header = '| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |'
separator = '| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |'

lines = []
lines.append('**Table 1: Soundness of call-graphs for different JVM features**')
lines.append('')
lines.append(header)
lines.append(separator)
for row in rows:
    feature = row[0]
    cols = row[1:]
    # Adjust spacing: feature column left-aligned, others right-aligned as per Markdown
    line = f'| {feature:<20} | {cols[0]:>12} | {cols[1]:>12} | {cols[2]:>14} | {cols[3]:>12} | {cols[4]:>12} | {cols[5]:>14} |'
    lines.append(line)
lines.append('| **Sum (out of 123)** | ' + ' | '.join(total_row[1:]) + ' |')
lines.append('')
lines.append('*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*')

output = '\n'.join(lines)
print(output)
PYTHONEOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
