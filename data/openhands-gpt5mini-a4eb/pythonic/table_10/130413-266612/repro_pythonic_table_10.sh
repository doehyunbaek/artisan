#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 10: Reasons for using functional and procedural code**

| Reason                        | Lambdas | Comp. | MRF | Proc. |
| ----------------------------- | ------: | ----: | --: | ----: |
| Coding time                   |      11 |    12 |  10 |     2 |
| Ease of use                   |       4 |    10 |   8 |     7 |
| Maintainability               |      14 |     9 |  14 |     6 |
| Performance                   |       7 |    28 |  23 |     6 |
| Readability/Understandability |      19 |    89 |  33 |    27 |
| Size                          |      41 |    76 |  39 |     — |
| Lack of knowledge             |       — |     — |   — |    16 |
| Project constraints           |       — |     — |   — |     5 |
| Simplify debugging            |       — |     — |   — |     9 |

EOTABLE

# Section 2: Artifact download
curl -L -sS -o /workspace/ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1"

# Section 3: Reproduction commands
# Unpack artifact and compute the table from RQ3ManualValidation.xlsx
unzip -q /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/artifact
python3 - << 'PY'
import pandas as pd
from collections import Counter
fn='/workspace/artifact/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx'
expected_labels=['Coding time','Ease of use','Maintainability','Performance','Readability/Understandability','Size','Lack of knowledge','Project constraints','Simplify debugging']
map_map = {
    'coding time':'Coding time',
    'readability/understandability':'Readability/Understandability',
    'performance':'Performance',
    'size':'Size',
    'maintainability':'Maintainability',
    'lack of knowledge':'Lack of knowledge',
    'project constraint':'Project constraints',
    'project constraints':'Project constraints',
    'debugging is easier':'Simplify debugging',
    'simplify debugging':'Simplify debugging',
    'ease of use':'Ease of use',
    'ease of use ':'Ease of use'
}

xls=pd.ExcelFile(fn)
results={}
for s in xls.sheet_names:
    df=pd.read_excel(fn, sheet_name=s)
    col='Final Classification'
    vals=df[col].astype(str).fillna('None').tolist()
    cnt=Counter()
    for v in vals:
        v2=v.strip()
        if v2 in ['nan','NaN','None','None'] or v2=='' or v2.lower()=='nan':
            continue
        key=map_map.get(v2.lower(), None)
        if key is None:
            lv=v2.lower()
            if 'coding' in lv:
                key='Coding time'
            elif 'readab' in lv:
                key='Readability/Understandability'
            elif 'perform' in lv:
                key='Performance'
            elif 'size' in lv:
                key='Size'
            elif 'maintain' in lv:
                key='Maintainability'
            elif 'lack' in lv:
                key='Lack of knowledge'
            elif 'project' in lv:
                key='Project constraints'
            elif 'debug' in lv:
                key='Simplify debugging'
            elif 'ease' in lv:
                key='Ease of use'
            else:
                key=v2
        cnt[key]+=1
    results[s]=cnt

# write reproduction output
out='/workspace/repro.txt'
with open(out,'w') as f:
    f.write('**Reproduced Table 10: Reasons for using functional and procedural code**\n\n')
    f.write('| Reason | Lambdas | Comp. | MRF | Proc. |\n')
    f.write('| ----------------------------- | ------: | ----: | --: | ----: |\n')
    for r in expected_labels:
        a=results['Lambda'].get(r,0)
        b=results['Comprehension'].get(r,0)
        c=results['MRF'].get(r,0)
        d=results['Procedural'].get(r,0)
        f.write(f'| {r} | {a:6d} | {b:5d} | {c:3d} | {d:5d} |\n')
print('Reproduction finished, output written to /workspace/repro.txt')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
