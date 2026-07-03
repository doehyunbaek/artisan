#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: The Match Accuracy and Reproduction Rate for RQ5**

|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |
| --------- | :---------------------: | :-------------------: |
| Roam-Sim  |            88           |           65          |
| Roam-Dist |            77           |           38          |
| Roam      |            93           |           94          |

EOTABLE

# Section 2: Artifact download
if [ ! -f /workspace/ROAM-Artifact.zip ]; then
  echo "Downloading ROAM-Artifact.zip from Zenodo..."
  curl -L "https://zenodo.org/records/11068809/files/ROAM-Artifact.zip?download=1" -o /workspace/ROAM-Artifact.zip
else
  echo "ROAM-Artifact.zip already exists, skipping download."
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract artifact
unzip -o /workspace/ROAM-Artifact.zip -d /workspace/ >/dev/null

# Convert results.pdf to markdown (requires uvx/pymupdf4llm helper)
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; open(sys.argv[1]+".md","w").write(p.to_markdown(sys.argv[1])); print(sys.argv[1]+".md saved")' /workspace/ROAM-Artifact/Evaluation/results.pdf

# Parse the converted markdown to compute the required metrics
python3 - << 'PY' > /workspace/repro.txt
path='/workspace/ROAM-Artifact/Evaluation/results.pdf.md'
lines=open(path).read().splitlines()
# Find table data lines: those starting with '|' and having a numeric first cell
data=[]
for line in lines:
    if not line.startswith('|'):
        continue
    parts=[p.strip() for p in line.split('|')]
    if len(parts)>2 and parts[1].isdigit():
        data.append(parts)

methods_counts={'Roam':{'matches':[],'success':0},'Roam-Sim':{'matches':[],'success':0},'Roam-Dist':{'matches':[],'success':0}}
for parts in data:
    tokens=parts[1:]
    found=[]
    for i in range(len(tokens)-1):
        t=tokens[i]
        t2=tokens[i+1].lower()
        t_clean=t.replace(',','')
        try:
            val=float(t_clean)
            if 0<=val<=1:
                if any(x in t2 for x in ['success','failure','false positive','false_positive','false-positive']):
                    found.append((val,t2))
        except:
            continue
        if len(found)>=3:
            break
    if len(found)>=3:
        for (name,(val,res)) in zip(['Roam','Roam-Sim','Roam-Dist'], found[:3]):
            methods_counts[name]['matches'].append(val)
            if 'success' in res:
                methods_counts[name]['success']+=1

# Compute aggregates and print a small table
total=len(data)
print('Reproduction results computed from artifact (total subjects =', total,')')
print()
print('| Method | Avg. Match Accuracy (%) | Reproduction Rate (%) | Success Count |')
print('|--------|:-----------------------:|:---------------------:|:-------------:|')
for name in ['Roam-Sim','Roam-Dist','Roam']:
    matches=methods_counts[name]['matches']
    succ=methods_counts[name]['success']
    avg=(sum(matches)/len(matches))*100 if matches else 0
    rate=succ/total*100 if total else 0
    print(f'| {name} | {avg:.2f} | {rate:.2f} | {succ} |')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
