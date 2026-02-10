#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ROAM-Artifact.zip https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content
unzip ROAM-Artifact.zip -d ROAM-Artifact
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results_md.md

python3 - <<'PY'
import re,statistics
with open('/workspace/results_md.md','r') as f:
    lines=[l.rstrip('\n') for l in f]
# collect table lines starting with '|'
table_lines=[l for l in lines if l.strip().startswith('|')]
if len(table_lines) < 4:
    raise SystemExit('No table found')
top = table_lines[0]
sep = table_lines[1]
sub = table_lines[2]
data = table_lines[3:]
def split_cells(line):
    parts=[c.strip() for c in line.split('|')]
    # remove leading/trailing empty cells produced by leading/trailing |
    if parts and parts[0]=='':
        parts=parts[1:]
    if parts and parts[-1]=='':
        parts=parts[:-1]
    return parts
top_cells=split_cells(top)
sub_cells=split_cells(sub)
# fill top header blanks by carrying previous non-empty
filled_top=[]
last=''
for c in top_cells:
    if c:
        last=c
        filled_top.append(c)
    else:
        filled_top.append(last)
# helper to parse numeric cells
def to_float(s):
    if s is None: return None
    s=s.strip()
    if s=='':
        return None
    s=s.replace(',','')
    m=re.match(r'(-?\d+(\.\d+)?)', s)
    if not m:
        return None
    try:
        return float(m.group(1))
    except:
        return None
# locate indices for ROAM PRM, Event Search, Path Recovery
prm_idx=ev_idx=path_idx=None
for i,c in enumerate(sub_cells):
    low=c.lower()
    if 'prm' in low and 'construction' in low:
        prm_idx=i
    if 'event' in low and 'search' in low:
        ev_idx=i
    if 'path' in low and 'recovery' in low:
        path_idx=i
# locate ReCDroid and Yakusu top indices
def find_tool_col(toolname):
    for i,c in enumerate(filled_top):
        if c.strip().lower()==toolname.lower():
            return i
    return None
recdroid_top_idx=find_tool_col('ReCDroid')
yakusu_top_idx=find_tool_col('Yakusu')
# for these tools, try to find the subcolumn that mentions 'Running'
def find_running_idx(top_idx):
    if top_idx is None:
        return None
    # try top_idx and neighbors up to +2
    for j in range(top_idx, min(top_idx+3, len(sub_cells))):
        if 'running' in sub_cells[j].lower():
            return j
    # fallback: return top_idx
    return top_idx

recdroid_idx=find_running_idx(recdroid_top_idx)
yakusu_idx=find_running_idx(yakusu_top_idx)

prm_vals=[]
ev_vals=[]
path_vals=[]
total_vals=[]
recdroid_vals=[]
yakusu_vals=[]
for row in data:
    cells=split_cells(row)
    # data rows start with index number; skip malformed
    if len(cells)==0: continue
    if not re.match(r'^\d+$', cells[0]):
        continue
    def gv(i):
        if i is None or i>=len(cells):
            return None
        return to_float(cells[i])
    p=gv(prm_idx)
    e=gv(ev_idx)
    pa=gv(path_idx)
    if p is not None and e is not None and pa is not None:
        prm_vals.append(p); ev_vals.append(e); path_vals.append(pa); total_vals.append(p+e+pa)
    rv=gv(recdroid_idx)
    if rv is not None:
        recdroid_vals.append(rv)
    yv=gv(yakusu_idx)
    if yv is not None:
        yakusu_vals.append(yv)

def stats(lst):
    if not lst:
        return (None,None)
    return (round(statistics.mean(lst),3), round(statistics.median(lst),3))

prm_mean,prm_med = stats(prm_vals)
ev_mean,ev_med = stats(ev_vals)
path_mean,path_med = stats(path_vals)
total_mean,total_med = stats(total_vals)
recdroid_mean,recdroid_med = stats(recdroid_vals)
yakusu_mean,yakusu_med = stats(yakusu_vals)

with open('/workspace/repro.txt','w') as out:
    out.write(f"ROAM_PRM_mean={prm_mean}\n")
    out.write(f"ROAM_PRM_median={prm_med}\n")
    out.write(f"ROAM_EventSearch_mean={ev_mean}\n")
    out.write(f"ROAM_EventSearch_median={ev_med}\n")
    out.write(f"ROAM_PathRecvExec_mean={path_mean}\n")
    out.write(f"ROAM_PathRecvExec_median={path_med}\n")
    out.write(f"ROAM_Total_mean={total_mean}\n")
    out.write(f"ROAM_Total_median={total_med}\n")
    out.write(f"ReCDroid_Total_mean={recdroid_mean}\n")
    out.write(f"ReCDroid_Total_median={recdroid_med}\n")
    out.write(f"Yakusu_Total_mean={yakusu_mean}\n")
    out.write(f"Yakusu_Total_median={yakusu_med}\n")
print('Wrote /workspace/repro.txt')
PY

echo '<artisan_submit>'
python3 - <<'PY'
import re
from math import floor

k={}
for l in open("/workspace/repro.txt",encoding="utf-8",errors="replace"):
    m=re.match(r"\s*([^=]+)=(.*)\s*$", l)
    if m:
        k[m.group(1).strip()] = float(m.group(2))

def round_half_up(x: float) -> int:
    return int(floor(x + 0.5))

def f0(x: float) -> str:
    return f"{round_half_up(x):,}"

# center with the "extra" space on the LEFT (matches expected)
def center_leftbias(s: str, width: int) -> str:
    s = str(s)
    pad = width - len(s)
    if pad <= 0:
        return s
    left = (pad + 1) // 2
    right = pad - left
    return (" " * left) + s + (" " * right)

print("**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**\n")
print("|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |")
print("| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |")
print("|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |")

# IMPORTANT: widths exclude the single spaces added by `| {cell} |`
W_PRM, W_EV, W_PATH, W_TOT, W_RC, W_YK = 12, 16, 20, 9, 8, 6

avg_prm  = center_leftbias(f0(k["ROAM_PRM_mean"]), W_PRM)
avg_ev   = center_leftbias(f0(k["ROAM_EventSearch_mean"]), W_EV)
avg_path = center_leftbias(f0(k["ROAM_PathRecvExec_mean"]), W_PATH)
avg_tot  = center_leftbias(f"**{f0(k['ROAM_Total_mean'])}**", W_TOT)
avg_rc   = center_leftbias(f0(k["ReCDroid_Total_mean"]), W_RC)
avg_yk   = center_leftbias(f0(k["Yakusu_Total_mean"]), W_YK)

mdn_prm  = center_leftbias(f0(k["ROAM_PRM_median"]), W_PRM)
mdn_ev   = center_leftbias(f0(k["ROAM_EventSearch_median"]), W_EV)
mdn_path = center_leftbias(f0(k["ROAM_PathRecvExec_median"]), W_PATH)
mdn_tot  = center_leftbias(f"**{f0(k['ROAM_Total_median'])}**", W_TOT)
mdn_rc   = center_leftbias(f0(k["ReCDroid_Total_median"]), W_RC)
mdn_yk   = center_leftbias(f0(k["Yakusu_Total_median"]), W_YK)

print(f"| **Avg.** | {avg_prm} | {avg_ev} | {avg_path} | {avg_tot} | {avg_rc} | {avg_yk} |")
print(f"| **Mdn.** | {mdn_prm} | {mdn_ev} | {mdn_path} | {mdn_tot} | {mdn_rc} | {mdn_yk} |")
print()  # newline at EOF
PY
echo '</artisan_submit>'
