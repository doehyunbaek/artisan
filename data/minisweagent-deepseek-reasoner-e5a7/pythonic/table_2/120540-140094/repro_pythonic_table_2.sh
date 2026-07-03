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
curl -L -o /workspace/artifact.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content"
# Section 3: Reproduction commands (populate from reviewed steps)
unzip -q /workspace/artifact.zip -d /workspace/artifact
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
./run-analysis.sh
cp results/Table-2-descriptive.csv /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 -c "
import csv
with open('/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-2-descriptive.csv', 'r') as f:
    reader = csv.DictReader(f)
    print('**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**')
    print()
    print('| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |')
    print('| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |')
    for row in reader:
        construct = row['Construct']
        if construct == 'lambda':
            display = 'Lambda'
        elif construct == 'comp':
            display = 'Compr.'
        elif construct == 'mrf':
            display = 'MRF'
        else:
            display = construct
        ftrue = row['Ftrue']
        ffalse = row['Ffalse']
        fperc = format(float(row['Fperc']), '.2f')
        ptrue = row['Ptrue']
        pfalse = row['Pfalse']
        pperc = format(float(row['Pperc']), '.2f')
        print(f'| {display:9} | {ftrue:>23} | {ffalse:>23} | {fperc:>24} | {ptrue:>23} | {pfalse:>23} | {pperc:>24} |')
"
echo '</artisan_submit>'
