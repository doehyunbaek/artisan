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
echo "Downloading artifact from Zenodo..."
curl -L -o /workspace/Unimocg_Artifact.zip "https://zenodo.org/api/records/10890011/files/Unimocg_Artifact.zip/content" 2>&1 | tee /workspace/download.log
echo "Extracting artifact..."
unzip -q /workspace/Unimocg_Artifact.zip -d /workspace/artifact 2>&1 | tee -a /workspace/download.log

# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running aggregation script on precomputed fingerprint files..." > /workspace/repro.txt
cd /workspace
# Copy runner script
cp -r /workspace/artifact/docker/runner /workspace/runner
# Run aggregation for each algorithm
for algo in CHA RTA XTA 0-CFA 1-1-CFA; do
    echo "===================================================================" >> /workspace/repro.txt
    echo "OPAL-$algo.profile" >> /workspace/repro.txt
    python3 /workspace/runner/aggregate_fingerprints.py /workspace/artifact/evaluation/fingerprints/OPAL-$algo.profile >> /workspace/repro.txt 2>&1
done

# Generate combined table using custom script
cat > /workspace/generate_table2.py <<'EOSCRIPT'
import csv, sys, os
def aggregate(filename):
    tsv_file = open(filename)
    read_tsv = csv.reader(tsv_file, delimiter="\t")
    keys = {
        'Non-virtual Calls':{'NVC'},
        'Virtual Calls':{'VC'},
        'Types':{'TC'},
        'Static Initializer':{'SI'},
        'Java 8 Interfaces':{'J8DIM', 'J8SIM'},
        'Unsafe':{'Unsafe'},
        'Class.forName':{'CFNE'},
        'Signature Polymorphic Methods':{'SPM'},
        'Java 9+':{'Java 9 Modules', 'J10SIM'},
        'Non-Java':{'NJ'},
        'MethodHandle':{'TMR'},
        'Invokedynamic':{'Lambda', 'MR'},
        'Reflection':{'TR', 'LRR', 'CSR'},
        'JVM Calls':{'JVMC'},
        'Serialization':{'Ser', 'ExtSer', 'SerLam'},
        'Library Analysis':{'LIB'},
        'Class Loading':{'CL'},
        'DynamicProxy':{'DP'}
    }
    result = {}; totals = {}; f = []
    for row in read_tsv: f.append(row)
    for key in keys:
        result[key] = 0; totals[key] = 0
        for v in keys[key]:
            for row in f:
                if row[0].startswith(v) and (row[0][len(v):] + "0").isdigit():
                    totals[key] += 1
                    if row[1]=='S' or row[1]=='I':
                        result[key] += 1
    return result, totals
algorithms = ['CHA', 'RTA', 'XTA', '0-CFA', '1-1-CFA']
base_dir = '/workspace/artifact/evaluation/fingerprints'
data = {}; totals = {}
for algo in algorithms:
    profile = os.path.join(base_dir, f'OPAL-{algo}.profile')
    res, tot = aggregate(profile); data[algo] = res; totals[algo] = tot
categories = list(data['CHA'].keys())
print("**Table 2: Soundness of Unimocg’s call-graph algorithms**")
print()
header = "| Feature              |"
for algo in algorithms: header += f"      **{algo}** |"
print(header)
sep = "| -------------------- |"
for _ in algorithms: sep += " -----------: |"
print(sep)
for cat in categories:
    line = f"| {cat:<20} |"
    for algo in algorithms:
        val = data[algo][cat]; tot = totals[algo][cat]
        line += f" {val:>2}/{tot:<2} |"
    print(line)
print("| **Sum (out of 123)** |", end="")
for algo in algorithms:
    total_sum = sum(data[algo].values())
    line = f" **{total_sum} ({int(round(total_sum/123*100))}%)** |"
    print(line, end="")
print()
print()
print("*Algorithms are ordered by increasing precision. “Soundness” values are test cases passed soundly (all/some/none).*")
EOSCRIPT

echo "Generating combined table..." >> /workspace/repro.txt
python3 /workspace/generate_table2.py >> /workspace/repro.txt 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'