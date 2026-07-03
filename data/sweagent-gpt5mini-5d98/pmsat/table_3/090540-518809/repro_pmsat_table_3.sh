#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | 0.5 | 0.3 | 0.5 | 1.5 | 3.5 | 5.8 | 10.3 | 17.5 | 27 | 33 |

EOTABLE
# Section 2: Artifact download
# downloaded already via Zenodo API into /workspace/pmsat-artifacts.zip and extracted to /workspace/artifacts

# Section 3: Reproduction commands (populate from reviewed steps)
python3 /workspace/artifacts/pmsat-inference/parse_all_results_timeouts.py /workspace/artifacts/pmsat-inference/benchmarkingset-rc2-results > /workspace/table3_raw.csv 2> /workspace/table3_log.txt || true
# post-process to match paper formatting (percentage of 400 experiments per n)
python3 - <<'PY'
import json,os
path='/workspace/artifacts/pmsat-inference/benchmarkingset-rc2-results'
counts={}
timeouts={}
for root,dirs,files in os.walk(path):
    for f in files:
        if f.endswith('.json'):
            fp=os.path.join(root,f)
            try:
                with open(fp) as fh:
                    data=json.load(fh)
            except Exception:
                continue
            if 'num_states' in data and 'timed_out' in data:
                n=data['num_states']
                counts[n]=counts.get(n,0)+1
                if data['timed_out']:
                    timeouts[n]=timeouts.get(n,0)+1
# focus on n=8..17
ns=list(range(8,18))
vals=[(timeouts.get(n,0), counts.get(n,0)) for n in ns]
# compute percent per 400 where counts==400
out=[]
for n,(to,tot) in zip(ns,vals):
    pct=round(100.0*to/tot,1) if tot>0 else 0
    out.append((n,to,tot,pct))
print('n,total,timeouts,percent')
for r in out:
    print(r)
# write to repro.txt
with open('/workspace/repro.txt','w') as f:
    f.write('n,total,timeouts,percent\n')
    for r in out:
        f.write(','.join(map(str,r))+"\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
