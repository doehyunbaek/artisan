#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5. Build technologies adopted after Bazel abandonment**

| Domain    | Build Technology   | # Projects | Language(s)                    |
| --------- | ------------------ | ---------: | ------------------------------ |
| D1        | Go Build           |         29 | Go                             |
| D1        | SPM                |          1 | Swift                          |
| D1        | Mage               |          1 | Go                             |
| D1        | SBT                |          1 | Scala                          |
| D1        | Gradle             |          1 | Java                           |
| D1        | Setuptools         |          1 | Python                         |
| D2        | CMake              |         11 | C++, Go, Python, Shell         |
| D2        | Make               |          9 | Go, JavaScript, C              |
| D3        | Nix                |          3 | Go, TypeScript, Scala, Haskell |
| D3        | Google Cloud Build |          4 | Go                             |
| **Total** |                    |     **61** |                                |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/artifact
curl -L -o /workspace/artifact/build-downgrade.zip "https://zenodo.org/records/10553683/files/build-downgrade.zip?download=1"
curl -L -o /workspace/artifact/0.README.md "https://zenodo.org/records/10553683/files/0.README.md?download=1"

# Section 3: Reproduction commands (populate from reviewed steps)
# Unzip the artifact, convert the labeled sheet to CSV, and aggregate replacements
unzip -q /workspace/artifact/build-downgrade.zip -d /workspace/artifact
python3 - << 'PY'
import pandas as pd
import csv, re
from collections import Counter
# convert excel sheet to CSV
xls = '/workspace/artifact/build-downgrade/study/3.thematic-analysis/bazel-abandonment-labels.xlsx'
df = pd.read_excel(xls, sheet_name='Labeled data')
csv_path = '/workspace/artifact/labeled_data.csv'
df.to_csv(csv_path, index=False)
# aggregate primary replacement technology per row
counts = Counter()
with open(csv_path, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for r in reader:
        raw = r.get('replaced-by','')
        if not raw or str(raw).strip()=='' or str(raw).strip().lower()=='nan':
            continue
        first = re.split(r'\+|,|/|\\n', raw)[0].strip()
        first = re.sub(r'\(.*?\)','', first).strip()
        key = first.lower()
        # check Google Cloud Build before the generic Go Build heuristic
        if 'google' in key and 'cloud' in key:
            counts['Google Cloud Build'] += 1
        elif 'go' in key and 'build' in key:
            counts['Go Build'] += 1
        elif 'cmake' in key:
            counts['CMake'] += 1
        elif 'make' in key:
            counts['Make'] += 1
        elif 'nix' in key:
            counts['Nix'] += 1
        elif 'swift' in key or 'spm' in key:
            counts['SPM'] += 1
        elif 'mage' in key:
            counts['Mage'] += 1
        elif 'sbt' in key:
            counts['SBT'] += 1
        elif 'setuptools' in key or 'python' in key:
            counts['Setuptools'] += 1
        elif 'gradle' in key:
            counts['Gradle'] += 1
        else:
            counts[first] += 1
# produce the reproduction table to repro.txt
out = '/workspace/repro.txt'
with open(out,'w',encoding='utf-8') as o:
    o.write('Build Technology,Count\n')
    for k in ['Go Build','SPM','Mage','SBT','Gradle','Setuptools','CMake','Make','Nix','Google Cloud Build']:
        o.write(f'{k},{counts.get(k,0)}\n')
print('WROTE', out)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
