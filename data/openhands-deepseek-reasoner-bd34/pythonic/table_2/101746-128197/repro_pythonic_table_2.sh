#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                    53.33 |                    115 |                     95 |                    54.76 |
| Compr.    |                     99 |                    111 |                    47.14 |                    114 |                     96 |                    54.29 |
| MRF       |                     80 |                    130 |                    38.10 |                     85 |                    125 |                    40.48 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact..."
curl -s -L "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content" -o /workspace/artifact.zip
echo "Unzipping artifact..."
unzip -q /workspace/artifact.zip -d /workspace
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running analysis with Docker..."
cd /workspace/ICSE2024-funcConstructs-Artifacts
cat FuncConstructs-Statistics.r | docker run --workdir /data -v${PWD}:/data --rm -i mdipenta/rexp R --no-save 2>&1 | tee /workspace/analysis.log
echo "Extracting Table 2..."
cp results/Table-2-descriptive.csv /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 <<'PYTHONSCRIPT'
import csv
import sys
with open('/workspace/repro.txt', 'r') as f:
    reader = csv.DictReader(f)
    rows = list(reader)
# Mapping construct names
construct_map = {'lambda': 'Lambda', 'comp': 'Compr.', 'mrf': 'MRF'}
print("**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**")
print()
print("| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |")
print("| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |")
for row in rows:
    construct = construct_map.get(row['Construct'], row['Construct'])
    fcorr = int(row['Ftrue'])
    fwrong = int(row['Ffalse'])
    fperc = round(float(row['Fperc']), 2)
    pcorr = int(row['Ptrue'])
    pwrong = int(row['Pfalse'])
    pperc = round(float(row['Pperc']), 2)
    print(f"| {construct:9} | {fcorr:>22} | {fwrong:>22} | {fperc:>24.2f} | {pcorr:>22} | {pwrong:>22} | {pperc:>24.2f} |")
PYTHONSCRIPT
echo '</artisan_submit>'
