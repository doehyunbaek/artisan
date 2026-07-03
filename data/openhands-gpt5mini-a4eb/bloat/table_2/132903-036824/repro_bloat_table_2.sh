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
# Download the artifact zip from Zenodo (v1.0)
curl -sL "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1" -o /workspace/bloat-study-artifact-v1.0.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract and compute the statistics for Table 2. Output to /workspace/repro.txt
unzip -o /workspace/bloat-study-artifact-v1.0.zip -d /workspace > /workspace/unzip_repro.log 2>&1

python3 - << 'PY' > /workspace/repro.txt
import csv
from statistics import mean, median
path='/workspace/gdrosos-bloat-study-artifact-0fe2fe5/data/results/rq1a.csv'
uniq_res=[]
uniq_un=[]
with open(path, newline='') as f:
    reader=csv.DictReader(f)
    for r in reader:
        ur=r.get('unique_resolved_count','').strip()
        uu=r.get('unique_unresolved_count','').strip()
        try:
            ur_v=float(ur) if ur!='' else None
        except:
            ur_v=None
        try:
            uu_v=float(uu) if uu!='' else None
        except:
            uu_v=None
        if ur_v is not None:
            uniq_res.append(ur_v)
        if uu_v is not None:
            uniq_un.append(uu_v)

sum_ur=int(sum(uniq_res))
sum_uu=int(sum(uniq_un))
prop_ur=100.0*sum(uniq_res)/(sum(uniq_res)+sum(uniq_un))
avg_ur=mean(uniq_res) if uniq_res else 0
avg_uu=mean(uniq_un) if uniq_un else 0
med_ur=median(uniq_res) if uniq_res else 0
med_uu=median(uniq_un) if uniq_un else 0

print('**Reproduction of Table 2: Statistics on resolved/unresolved external calls**')
print('')
print('|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |')
print('| --- | --- | --- | --- | --- | --- |')
print('|  |  |  |  |  |  |')
print(f"|  | Resolved | {sum_ur:,} | {prop_ur:.1f}% | {round(avg_ur):,} | {med_ur} |")
print(f"|  | Unresolved | {sum_uu:,} | {100-prop_ur:.1f}% | {round(avg_uu):,} | {med_uu} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
