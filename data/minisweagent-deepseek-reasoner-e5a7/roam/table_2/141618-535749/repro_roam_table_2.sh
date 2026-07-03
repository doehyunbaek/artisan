#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**

|                 | Match Accuracy | Perfect Cases   | Zero Cases  |
| --------------- | :------------: | :-----------:   | :--------:  |
| PRM-Enumeration |       61       |       56      |     33     |
| Euler           |       72       |       56      |     14     |
| Roam            |       93       |       85      |      0     |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact from Zenodo..."
curl -L -o /workspace/artifact.zip "https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content"
unzip -o /workspace/artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Extracting Table 2 results from evaluation data..."
cd /workspace/artifact/ROAM-Artifact
# Convert results PDF to markdown and compute statistics
python3 << 'PYTHON_EOF'
import csv
import sys
import subprocess
import json

# First convert the PDF to markdown
print("Converting results PDF to markdown...")
result = subprocess.run([
    'uvx', '--from', 'pymupdf4llm', 'python', '-c',
    'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))',
    'Evaluation/results.pdf'
], capture_output=True, text=True)

if result.returncode != 0:
    print("Failed to convert PDF")
    sys.exit(1)

lines = result.stdout.split('\n')
# Find the start of the table
table_start = 0
for i, line in enumerate(lines):
    if line.startswith('|Col1|'):
        table_start = i
        break

if table_start == 0:
    print("Table not found in PDF")
    sys.exit(1)

# Parse data rows
data_rows = []
for line in lines[table_start+2:]:
    if not line.startswith('|'):
        continue
    parts = line.split('|')[1:-1]
    if len(parts) < 10:
        continue
    # Ensure we have exactly 56 columns
    if len(parts) < 56:
        parts.extend([''] * (56 - len(parts)))
    elif len(parts) > 56:
        parts = parts[:56]
    data_rows.append(parts)

# Column indices based on analysis
roam_idx = 6    # ROAM match accuracy
prm_idx = 18    # PRM-Enumeration match accuracy
euler_idx = 20  # Euler match accuracy

# Compute statistics
def parse_val(v):
    if not v or v.strip() == '':
        return None
    try:
        return float(v)
    except:
        return None

roam_accuracies = []
prm_accuracies = []
euler_accuracies = []

for row in data_rows:
    if len(row) > max(roam_idx, prm_idx, euler_idx):
        roam_val = row[roam_idx]
        prm_val = row[prm_idx]
        euler_val = row[euler_idx]
        
        roam_f = parse_val(roam_val)
        prm_f = parse_val(prm_val)
        euler_f = parse_val(euler_val)
        
        if roam_f is not None:
            roam_accuracies.append(roam_f)
        if prm_f is not None:
            prm_accuracies.append(prm_f)
        if euler_f is not None:
            euler_accuracies.append(euler_f)

def avg(lst):
    return sum(lst)/len(lst) if lst else 0

def percent(val):
    return int(round(val * 100))

roam_avg = percent(avg(roam_accuracies))
prm_avg = percent(avg(prm_accuracies))
euler_avg = percent(avg(euler_accuracies))

roam_perfect = percent(sum(1 for x in roam_accuracies if x == 1) / len(roam_accuracies))
prm_perfect = percent(sum(1 for x in prm_accuracies if x == 1) / len(prm_accuracies))
euler_perfect = percent(sum(1 for x in euler_accuracies if x == 1) / len(euler_accuracies))

roam_zero = percent(sum(1 for x in roam_accuracies if x == 0) / len(roam_accuracies))
prm_zero = percent(sum(1 for x in prm_accuracies if x == 0) / len(prm_accuracies))
euler_zero = percent(sum(1 for x in euler_accuracies if x == 0) / len(euler_accuracies))

# Save results to file
results = {
    "PRM-Enumeration": {
        "Match Accuracy": prm_avg,
        "Perfect Cases": prm_perfect,
        "Zero Cases": prm_zero
    },
    "Euler": {
        "Match Accuracy": euler_avg,
        "Perfect Cases": euler_perfect,
        "Zero Cases": euler_zero
    },
    "Roam": {
        "Match Accuracy": roam_avg,
        "Perfect Cases": roam_perfect,
        "Zero Cases": roam_zero
    }
}

with open('/workspace/repro.txt', 'w') as f:
    f.write("Reproduced Table 2 Results:\n")
    f.write(f"PRM-Enumeration: Match Accuracy = {prm_avg}%, Perfect Cases = {prm_perfect}%, Zero Cases = {prm_zero}%\n")
    f.write(f"Euler: Match Accuracy = {euler_avg}%, Perfect Cases = {euler_perfect}%, Zero Cases = {euler_zero}%\n")
    f.write(f"Roam: Match Accuracy = {roam_avg}%, Perfect Cases = {roam_perfect}%, Zero Cases = {roam_zero}%\n")

print("Results written to /workspace/repro.txt")

# Also output for the artisan_submit block
print('\n<artisan_submit>')
print('**Table 2: The Match Accuracy Results on Bug Reports (Shown as a Percent)**')
print()
print('|                 | Match Accuracy | Perfect Cases   | Zero Cases  |')
print('| --------------- | :------------: | :-----------:   | :--------:  |')
print(f'| PRM-Enumeration |       {prm_avg}       |       {prm_perfect}      |     {prm_zero}     |')
print(f'| Euler           |       {euler_avg}       |       {euler_perfect}      |     {euler_zero}     |')
print(f'| Roam            |       {roam_avg}       |       {roam_perfect}      |      {roam_zero}     |')
print('</artisan_submit>')
PYTHON_EOF
# Section 4: Formatting and submission block
# The Python script above already outputs the artisan_submit block
