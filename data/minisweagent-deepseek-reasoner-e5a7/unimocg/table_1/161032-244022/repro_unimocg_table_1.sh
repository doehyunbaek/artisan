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
unzip -q /workspace/Unimocg_Artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running aggregation script for Table 1..."
cd /workspace/artifact
python3 docker/runner/aggregate_fingerprints.py evaluation/fingerprints/WALA-CHA.profile evaluation/fingerprints/WALA-RTA.profile evaluation/fingerprints/WALA-0-CFA.profile evaluation/fingerprints/Soot-CHA.profile evaluation/fingerprints/Soot-RTA.profile evaluation/fingerprints/Soot-SPARK.profile > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Read the aggregation output and format as table
python3 <<'PYSCRIPT'
import re
import sys

# Read the reproduction output
with open('/workspace/repro.txt', 'r') as f:
    content = f.read()

# Split by profile sections
sections = content.split('===================================================================\n')[1:]

results = {}
for section in sections:
    lines = section.strip().split('\n')
    profile_name = lines[0].replace('.profile', '')
    algorithm = profile_name.split('-')[1]
    framework = profile_name.split('-')[0]
    
    # Extract the data
    data = {}
    for line in lines[2:]:
        if line.startswith('Sum'):
            break
        if ':' in line:
            key, value = line.split(': ')
            data[key] = value
    
    # Store in results dictionary
    key = f"{framework} — {algorithm}"
    results[key] = data

# Define the order of columns as in Table 1
columns = ['WALA — CHA', 'WALA — RTA', 'WALA — 0-CFA', 'Soot — CHA', 'Soot — RTA', 'Soot — SPARK']

# Define the features in order
features = [
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
    'DynamicProxy'
]

# Print the table header
print("**Table 1: Soundness of call-graphs for different JVM features**")
print()
print("| Feature              | **WALA — CHA** | **WALA — RTA** | **WALA — 0-CFA** | **Soot — CHA** | **Soot — RTA** | **Soot — SPARK** |")
print("| -------------------- | -------------: | -------------: | ---------------: | -------------: | -------------: | ---------------: |")

# Print each row
for feature in features:
    row = [feature]
    for col in columns:
        if col in results and feature in results[col]:
            row.append(results[col][feature])
        else:
            row.append('N/A')
    # Format the row with proper alignment
    print(f"| {row[0]:20} | {row[1]:^13} | {row[2]:^13} | {row[3]:^15} | {row[4]:^13} | {row[5]:^13} | {row[6]:^15} |")

# Calculate sums from the output
sums = {}
for section in sections:
    lines = section.strip().split('\n')
    profile_name = lines[0].replace('.profile', '')
    algorithm = profile_name.split('-')[1]
    framework = profile_name.split('-')[0]
    key = f"{framework} — {algorithm}"
    
    for line in lines:
        if line.startswith('Sum'):
            # Extract the sum value, e.g., "51 (41.46341463414634)"
            match = re.search(r'Sum \(out of 123\): (\d+)', line)
            if match:
                sums[key] = match.group(1)

# Print the sum row
print("| **Sum (out of 123)** |", end="")
for col in columns:
    if col in sums:
        print(f"   **{sums[col]} ({int(sums[col])/123*100:.0f}%)**", end="")
    else:
        print("   **N/A**", end="")
    if col != columns[-1]:
        print(" |", end="")
    else:
        print(" |")

print()
print("*Algorithms within each framework are ordered by increasing precision. “Soundness” column values are test cases passed soundly (all/some/none).*")
PYSCRIPT
echo '</artisan_submit>'
