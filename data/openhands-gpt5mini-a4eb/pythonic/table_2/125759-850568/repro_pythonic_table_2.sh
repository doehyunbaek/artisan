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
# Download the replication package from Zenodo
curl -L -o /workspace/ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content"

# Section 3: Reproduction commands
# Extract artifact
unzip -o /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace

# Compute Table 2 from the provided CSV (RQ1Paired-RQ2.csv)
python3 - << 'PY'
import csv
from pathlib import Path
p=Path('/workspace/ICSE2024-funcConstructs-Artifacts/working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1Paired-RQ2.csv')
rows=list(csv.DictReader(p.open()))
constructs=[('Lambda','LambdaF','LambdaP'),('Compr.','CompF','CompP'),('MRF','MrfF','MrfP')]
out=[]
for name,cf,cp in constructs:
    func_corr=sum(1 for r in rows if r.get(cf,'').strip().upper()=='TRUE')
    func_wrong=sum(1 for r in rows if r.get(cf,'').strip().upper()=='FALSE')
    proc_corr=sum(1 for r in rows if r.get(cp,'').strip().upper()=='TRUE')
    proc_wrong=sum(1 for r in rows if r.get(cp,'').strip().upper()=='FALSE')
    fden=func_corr+func_wrong
    pden=proc_corr+proc_wrong
    fperc=(func_corr/fden*100) if fden>0 else 0
    pperc=(proc_corr/pden*100) if pden>0 else 0
    out.append((name,func_corr,func_wrong,round(fperc,2),proc_corr,proc_wrong,round(pperc,2)))
with open('/workspace/repro.txt','w') as fo:
    fo.write('Construct,Functional-Corr,Functional-Wrong,Functional-%Corr,Procedural-Corr,Procedural-Wrong,Procedural-%Corr\n')
    for row in out:
        fo.write(','.join(str(x) for x in row)+"\n")
# Print human-readable table
print('**Reproduced Table 2**\n')
print('| Construct | Functional — Corr. | Functional — Wrong | Functional — % Corr. | Procedural — Corr. | Procedural — Wrong | Procedural — % Corr. |')
print('| --------- | -----------------: | ------------------: | --------------------: | ------------------: | -------------------: | ----------------------: |')
for name,fc,fw,fp,pc,pw,pp in out:
    print(f'| {name:7} | {fc:18d} | {fw:19d} | {fp:22.2f} | {pc:19d} | {pw:19d} | {pp:22.2f} |')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Output the reproduction results (CSV)
cat /workspace/repro.txt
echo '</artisan_submit>'
