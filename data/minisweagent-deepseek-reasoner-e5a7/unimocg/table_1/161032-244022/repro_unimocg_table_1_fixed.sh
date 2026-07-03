#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Soundness of call-graphs for different JVM features**

| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |
| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |
| Non-virtual Calls    |            6/6 |            6/6 |              6/6 |            6/6 |            6/6 |              6/6 |
| Virtual Calls        |            4/4 |            4/4 |              4/4 |            4/4 |            4/4 |              4/4 |
| Types                |            6/6 |            6/6 |              6/6 |            6/6 |            6/6 |              6/6 |
| Static Initializer   |            4/8 |            7/8 |              6/8 |            7/8 |            7/8 |              7/8 |
| Java 8 Interfaces    |            7/7 |            7/7 |              7/7 |            7/7 |            7/7 |              7/7 |
| Unsafe               |            7/7 |            7/7 |              0/7 |            7/7 |            7/7 |              0/7 |
| Class.forName        |            2/4 |            4/4 |              4/4 |            2/4 |            2/4 |              2/4 |
| Sign. Polymorph.     |            0/7 |            0/7 |              0/7 |            0/7 |            0/7 |              0/7 |
| Java 9+              |            2/2 |            1/2 |              1/2 |            2/2 |            2/2 |              2/2 |
| Non-Java             |            2/2 |            2/2 |              2/2 |            0/2 |            0/2 |              0/2 |
| MethodHandle         |            2/9 |            2/9 |              0/9 |            2/9 |            2/9 |              0/9 |
| Invokedynamic        |           0/16 |          10/16 |            10/16 |          11/16 |          11/16 |            11/16 |
| Reflection           |           2/16 |           3/16 |             6/16 |           2/16 |           2/16 |             0/16 |
| JVM Calls            |            2/5 |            3/5 |              3/5 |            4/5 |            4/5 |              3/5 |
| Serialization        |           3/14 |           1/14 |             1/14 |           3/14 |           1/14 |             1/14 |
| Library Analysis     |            2/5 |            2/5 |              1/5 |            2/5 |            2/5 |              2/5 |
| Class Loading        |            0/4 |            0/4 |              0/4 |            0/4 |            0/4 |              0/4 |
| DynamicProxy         |            0/1 |            0/1 |              0/1 |            0/1 |            0/1 |              0/1 |
| **Sum (out of 123)** |   **51 (41%)** |   **65 (53%)** |     **57 (46%)** |   **65 (53%)** |   **63 (51%)** |     **51 (41%)** |

*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact from Zenodo..."
curl -L -o /workspace/Unimocg_Artifact.zip "https://zenodo.org/api/records/10890011/files/Unimocg_Artifact.zip/content"
echo "Extracting artifact..."
unzip -q -o /workspace/Unimocg_Artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands
echo "Running aggregation script for Table 1..."
cd /workspace/artifact
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/WALA-CHA.profile > /tmp/wala_cha.txt 2>&1
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/WALA-RTA.profile > /tmp/wala_rta.txt 2>&1
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/WALA-0-CFA.profile > /tmp/wala_0cfa.txt 2>&1
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/Soot-CHA.profile > /tmp/soot_cha.txt 2>&1
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/Soot-RTA.profile > /tmp/soot_rta.txt 2>&1
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/Soot-SPARK.profile > /tmp/soot_spark.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 <<'PYSCRIPT'
import re

def parse_file(filename):
    data = {}
    with open(filename, 'r') as f:
        lines = f.readlines()
        for line in lines:
            line = line.strip()
            if line.startswith('Sum'):
                match = re.search(r'Sum \(out of 123\): (\d+)', line)
                if match:
                    data['Sum'] = int(match.group(1))
                continue
            if ':' in line:
                key, value = line.split(': ')
                data[key] = value
    return data

profiles = {
    'WALA — CHA': '/tmp/wala_cha.txt',
    'WALA — RTA': '/tmp/wala_rta.txt',
    'WALA — 0-CFA': '/tmp/wala_0cfa.txt',
    'Soot — CHA': '/tmp/soot_cha.txt',
    'Soot — RTA': '/tmp/soot_rta.txt',
    'Soot — SPARK': '/tmp/soot_spark.txt'
}

feature_mapping = {
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
    'DynamicProxy': 'DynamicProxy'
}

features = list(feature_mapping.keys())

table_data = {}
sums = {}
for profile_name, filename in profiles.items():
    parsed = parse_file(filename)
    table_data[profile_name] = parsed
    sums[profile_name] = parsed.get('Sum', 0)

# Print the table header
print("**Table 1: Soundness of call-graphs for different JVM features**")
print()
print("| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |")
print("| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |")

# Print each row
for orig_feature in features:
    display_feature = feature_mapping[orig_feature]
    row = [display_feature]
    for profile in profiles.keys():
        value = table_data[profile].get(orig_feature, 'N/A')
        row.append(value)
    print(f"| {row[0]:20} | {row[1]:^13} | {row[2]:^13} | {row[3]:^15} | {row[4]:^13} | {row[5]:^13} | {row[6]:^15} |")

# Print the sum row
print("| **Sum (out of 123)** |", end="")
for profile in profiles.keys():
    sum_val = sums[profile]
    percentage = int((sum_val / 123) * 100)
    print(f"   **{sum_val} ({percentage}%)**", end="")
    if profile != list(profiles.keys())[-1]:
        print(" |", end="")
    else:
        print(" |")

print()
print("*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*")
PYSCRIPT
echo '</artisan_submit>'
