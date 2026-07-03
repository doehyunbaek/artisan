#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      19      |        16        |          470         |  **505**  |   2,674  |  3,354 |
| **Mdn.** |       1      |         1        |          111         |  **150**  |   3,600  |  3,600 |

EOTABLE

# Section 2: Artifact download
curl -sL -o /workspace/ROAM-Artifact.zip "https://zenodo.org/records/11068809/files/ROAM-Artifact.zip?download=1"

# Section 3: Reproduction commands
# 1) extract the results.pdf from the artifact
unzip -p /workspace/ROAM-Artifact.zip "ROAM-Artifact/Evaluation/results.pdf" > /workspace/results.pdf

# 2) convert the PDF to markdown (requires uvx/pymupdf4llm)
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' /workspace/results.pdf > /workspace/results.md

# 3) compute the aggregated running-time statistics (avg and median)
python3 - <<'PY'
from statistics import mean,median
lines=open('/workspace/results.md').read().splitlines()
# locate header and data
for i,l in enumerate(lines):
    if 'Issue id' in l:
        hdr_line = l
        tool_line = lines[i-2]
        start = i+1
        break
# header cell indices determined from the markdown layout
prm_idx=10; evt_idx=11; path_idx=12; total_idx=9
# map ReCDroid and Yakusu via the tool grouping line
tool_cells=[p.strip() for p in tool_line.split('|')]
# find tool header indices and map the running-time header to the same index in data rows
# compute the running-time hdr positions and assign to nearest preceding tool
hdr_cells=[p.strip() for p in hdr_line.split('|')]
run_positions=[idx for idx,p in enumerate(hdr_cells) if 'Running' in p]
# determine tool indices that are non-Col entries
tool_indices=[idx for idx,p in enumerate(tool_cells) if p and not p.startswith('Col')]
# build mapping from run_position -> tool (nearest preceding)
mapping=[]
for r in run_positions:
    candidates=[t for t in tool_indices if t<=r]
    if not candidates: continue
    t=max(candidates)
    mapping.append((r,t,tool_cells[t]))
# find ReCDroid and Yakusu hdr indices
recdroid_hdr = [r for r,t,name in mapping if name=='ReCDroid'][0]
yakusu_hdr = [r for r,t,name in mapping if name=='Yakusu'][0]
# parse rows and collect values
rows=[ [p.strip() for p in l.split('|')] for l in lines[start:] if l.strip().startswith('|') ]
def tonum(s):
    s=s.strip()
    try:
        return float(s)
    except:
        return None
prm_vals=[]; evt_vals=[]; path_vals=[]; total_vals=[]; rec_vals=[]; yak_vals=[]
for parts in rows:
    def get(i):
        return tonum(parts[i]) if i < len(parts) else None
    total = get(total_idx)
    prm = get(prm_idx)
    evt = get(evt_idx)
    path = get(path_idx)
    rec = get(recdroid_hdr)
    yak = get(yakusu_hdr)
    if total is not None: total_vals.append(total)
    if prm is not None: prm_vals.append(prm)
    if evt is not None: evt_vals.append(evt)
    if path is not None: path_vals.append(path)
    if rec is not None: rec_vals.append(rec)
    if yak is not None: yak_vals.append(yak)
# format output as integers
print('PRM avg mdn', round(mean(prm_vals)), round(median(prm_vals)))
print('Event avg mdn', round(mean(evt_vals)), round(median(evt_vals)))
print('Path avg mdn', round(mean(path_vals)), round(median(path_vals)))
print('Total avg mdn', round(mean(total_vals)), round(median(total_vals)))
print('ReCDroid avg mdn', round(mean(rec_vals)), round(median(rec_vals)))
print('Yakusu avg mdn', round(mean(yak_vals)), round(median(yak_vals)))
open('/workspace/repro.txt','w').write('\n'.join([f'PRM avg mdn {round(mean(prm_vals))} {round(median(prm_vals))}', f'Event avg mdn {round(mean(evt_vals))} {round(median(evt_vals))}', f'Path avg mdn {round(mean(path_vals))} {round(median(path_vals))}', f'Total avg mdn {round(mean(total_vals))} {round(median(total_vals))}', f'ReCDroid avg mdn {round(mean(rec_vals))} {round(median(rec_vals))}', f'Yakusu avg mdn {round(mean(yak_vals))} {round(median(yak_vals))}']))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
