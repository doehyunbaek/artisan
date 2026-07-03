#!/usr/bin/bash
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

# Section 3: Reproduction commands (populate from reviewed steps)
# Use the artifact's aggregation script on the five OPAL algorithms and format as Table 2.
python3 - <<'PY' > /workspace/repro.txt
import pathlib
import subprocess
import re

base = pathlib.Path('Unimocg_Artifact')
runner = base / 'docker' / 'runner' / 'aggregate_fingerprints.py'

# Map algorithms to their OPAL profile files
alg_profiles = {
    'CHA':   base / 'evaluation' / 'fingerprints' / 'OPAL-CHA.profile',
    'RTA':   base / 'evaluation' / 'fingerprints' / 'OPAL-RTA.profile',
    'XTA':   base / 'evaluation' / 'fingerprints' / 'OPAL-XTA.profile',
    '0-CFA': base / 'evaluation' / 'fingerprints' / 'OPAL-0-CFA.profile',
    '1-1-CFA': base / 'evaluation' / 'fingerprints' / 'OPAL-1-1-CFA.profile',
}

# Run the official aggregation to reproduce the per-category results
cmd = ['python3', str(runner)] + [str(p) for p in alg_profiles.values()]
out = subprocess.check_output(cmd, text=True)

# Parse aggregation output
data = {alg: {} for alg in alg_profiles}
sums = {}
profile_to_alg = {
    'OPAL-CHA.profile': 'CHA',
    'OPAL-RTA.profile': 'RTA',
    'OPAL-XTA.profile': 'XTA',
    'OPAL-0-CFA.profile': '0-CFA',
    'OPAL-1-1-CFA.profile': '1-1-CFA',
}

current_alg = None
profile_re = re.compile(r'^Unimocg_Artifact/evaluation/fingerprints/(OPAL-[^/]+\.profile)$')

for line in out.splitlines():
    line = line.strip()
    if not line:
        continue

    m = profile_re.match(line)
    if m:
        prof = m.group(1)
        current_alg = profile_to_alg.get(prof)
        continue

    if current_alg is None:
        continue

    if line.startswith('Sum (out of'):
        m = re.search(r':\s*(\d+)\s*\(([\d\.Ee+-]+)\)', line)
        if m:
            total = int(m.group(1))
            pct = float(m.group(2))
            sums[current_alg] = (total, round(pct))
        continue

    m = re.match(r'([^:]+):\s*(\d+/\d+)', line)
    if m:
        cat = m.group(1).strip()
        val = m.group(2)
        data[current_alg][cat] = val

# Ordered feature rows: (key in aggregation output, label for the paper table)
rows = [
    ('Non-virtual Calls',           'Non-virtual Calls'),
    ('Virtual Calls',               'Virtual Calls'),
    ('Types',                       'Types'),
    ('Static Initializer',          'Static Initializer'),
    ('Java 8 Interfaces',           'Java 8 Interfaces'),
    ('Unsafe',                      'Unsafe'),
    ('Class.forName',               'Class.forName'),
    ('Signature Polymorphic Methods','Sign. Polymorph.'),
    ('Java 9+',                     'Java 9+'),
    ('Non-Java',                    'Non-Java'),
    ('MethodHandle',                'MethodHandle'),
    ('Invokedynamic',               'Invokedynamic'),
    ('Reflection',                  'Reflection'),
    ('JVM Calls',                   'JVM Calls'),
    ('Serialization',               'Serialization'),
    ('Library Analysis',            'Library Analysis'),
    ('Class Loading',               'Class Loading'),
    ('DynamicProxy',                'DynamicProxy'),
]

algs = ['CHA', 'RTA', 'XTA', '0-CFA', '1-1-CFA']

print('**Table 2: Soundness of Unimocg’s call-graph algorithms**\n')

header = '| Feature              |      **CHA** |      **RTA** |      **XTA** |    **0-CFA** |   **1-1-CFA** |'
sep    = '| -------------------- | -----------: | -----------: | -----------: | -----------: | ------------: |'
print(header)
print(sep)

for key, label in rows:
    row = [f'| {label:<20} ']
    for alg in algs:
        val = data[alg].get(key, '?/?')
        row.append(f'| {val:>11} ')
    row.append('|')
    print(''.join(row))

# Sum row
print('| **Sum (out of 123)** |', end='')
for alg in algs:
    total, pct = sums[alg]
    cell = f'**{total} ({pct}%)**'
    print(f' {cell:>11} |', end='')
print('\n')

print('*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
