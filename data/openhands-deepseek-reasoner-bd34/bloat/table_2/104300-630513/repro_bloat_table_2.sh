#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved | 7,799,929 | 96.8% | 5,991 | 144.5 |
|  | Unresolved | 260,249 | 3.2% | 200 | 11.5 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact..."
curl -L -o /tmp/artifact.zip "https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content"
echo "Extracting artifact..."
unzip -q /tmp/artifact.zip -d /tmp/
ARTIFACT_DIR="/tmp/gdrosos-bloat-study-artifact-0fe2fe5"
# Section 3: Reproduction commands
echo "Installing dependencies..."
cd "$ARTIFACT_DIR"
pip install -r requirements.txt > /dev/null 2>&1
echo "Running evaluation script..."
python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the output as markdown table using Python
python3 <<'EOF'
import sys
import re
# Read the generated output
with open('/workspace/repro.txt', 'r') as f:
    lines = f.readlines()
resolved = None
unresolved = None
for line in lines:
    line = line.rstrip()
    if line.startswith('Resolved'):
        parts = line.split()
        resolved = parts
    elif line.startswith('Unresolved'):
        parts = line.split()
        unresolved = parts
if not resolved or not unresolved:
    print("Error: Could not parse output")
    sys.exit(1)
rc = int(resolved[1])
rp = float(resolved[2])
ra = float(resolved[3])
rm = float(resolved[4])
uc = int(unresolved[1])
up = float(unresolved[2])
ua = float(unresolved[3])
um = float(unresolved[4])
# Print markdown table
print("**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**")
print()
print("|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |")
print("| --- | --- | --- | --- | --- | --- |")
print("|  |  |  |  |  |  |")
print(f"|  | Resolved | {rc:,} | {rp:.1f}% | {ra:.0f} | {rm:.1f} |")
print(f"|  | Unresolved | {uc:,} | {up:.1f}% | {ua:.0f} | {um:.1f} |")
EOF
echo '</artisan_submit>'