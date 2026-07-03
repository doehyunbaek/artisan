#!/usr/bin/bash
# Section 1: Expected table
# expected.md is provided in /workspace and contains Table 1.

# Section 2: Artifact download
cd /workspace
if [ ! -f Unimocg_Artifact.zip ]; then
  curl -L -o Unimocg_Artifact.zip https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip
fi
if [ ! -d Unimocg_Artifact ]; then
  unzip -q Unimocg_Artifact.zip -d Unimocg_Artifact
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract Table 1 data for WALA and Soot from the fingerprint summary
python3 - << 'PY'
import pathlib
import re

summary_path = pathlib.Path('/workspace/Unimocg_Artifact/summaries/summary_results_fingerprint.txt')
text = summary_path.read_text()

profiles_to_use = {
    'WALA-CHA.profile': 'WALA — CHA',
    'WALA-RTA.profile': 'WALA — RTA',
    'WALA-0-CFA.profile': 'WALA — 0-CFA',
    'Soot-CHA.profile': 'Soot — CHA',
    'Soot-RTA.profile': 'Soot — RTA',
    'Soot-SPARK.profile': 'Soot — SPARK',
}

category_label_map = {
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

row_order = [
    'Non-virtual Calls',
    'Virtual Calls',
    'Types',
    'Static Initializer',
    'Java 8 Interfaces',
    'Unsafe',
    'Class.forName',
    'Sign. Polymorph.',
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

cols = [
    'WALA — CHA',
    'WALA — RTA',
    'WALA — 0-CFA',
    'Soot — CHA',
    'Soot — RTA',
    'Soot — SPARK',
]

data = {col: {} for col in cols}

for chunk in text.split('==================================================================='):
    lines = [ln.rstrip() for ln in chunk.strip().splitlines()]
    if not lines:
        continue
    header = lines[0].strip()
    if header not in profiles_to_use:
        continue
    col = profiles_to_use[header]
    col_data = data[col]
    for ln in lines[2:]:  # skip header and following blank line
        ln = ln.strip()
        if not ln:
            continue
        if ln.startswith('Sum (out of 123):'):
            m = re.search(r'Sum \(out of 123\):\s+(\d+)', ln)
            if m:
                col_data['__sum__'] = int(m.group(1))
            break
        m = re.match(r'([^:]+):\s+(\d+/\d+)', ln)
        if m:
            src_name = m.group(1).strip()
            val = m.group(2).strip()
            out_label = category_label_map.get(src_name)
            if out_label is not None:
                col_data[out_label] = val

out_lines = []
out_lines.append('**Table 1: Soundness of call-graphs for different JVM features**')
out_lines.append('')
out_lines.append('| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |')
out_lines.append('| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |')

for row in row_order:
    row_vals = [data[col][row] for col in cols]
    out_lines.append(f"| {row:<20} | {row_vals[0]:>11} | {row_vals[1]:>11} | {row_vals[2]:>14} | {row_vals[3]:>11} | {row_vals[4]:>11} | {row_vals[5]:>14} |")

sum_vals = [data[col]['__sum__'] for col in cols]
percentages = [round(val * 100 / 123) for val in sum_vals]
formatted_sums = [f"**{v} ({p}%)**" for v, p in zip(sum_vals, percentages)]
out_lines.append(f"| **Sum (out of 123)** | {formatted_sums[0]:>11} | {formatted_sums[1]:>11} | {formatted_sums[2]:>14} | {formatted_sums[3]:>11} | {formatted_sums[4]:>11} | {formatted_sums[5]:>14} |")
out_lines.append('')
out_lines.append('*Algorithms within each framework are ordered by increasing precision. "Soundness" column values are test cases passed soundly (all/some/none).*')

repro_path = pathlib.Path('/workspace/repro.txt')
repro_path.write_text('\n'.join(out_lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
