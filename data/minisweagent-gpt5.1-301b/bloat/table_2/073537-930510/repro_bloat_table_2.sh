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
set -e
cd /workspace
if [ ! -f bloat-study-artifact-v1.0.zip ]; then
  curl -L -o bloat-study-artifact-v1.0.zip "https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content"
fi
rm -rf /workspace/bloat-artifact
unzip -d /workspace/bloat-artifact /workspace/bloat-study-artifact-v1.0.zip

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/bloat-artifact/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
docker rm -f bloat-table2 >/dev/null 2>&1 || true
docker run -d --init --name bloat-table2 --entrypoint bash \
  -v "$(pwd)/scripts":/home/user/scripts \
  -v "$(pwd)/data":/home/user/data \
  -v "$(pwd)/figures":/home/user/figures \
  bloat-study-artifact -c 'sleep infinity'
docker exec bloat-table2 /bin/bash --noprofile --norc -c "cd /home/user && python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv" > /workspace/repro.txt
docker rm -f bloat-table2 >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - <<'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/bloat-artifact/gdrosos-bloat-study-artifact-0fe2fe5/data/results/rq1a.csv")

total_resolved = 0
total_unresolved = 0
projects = 0

with csv_path.open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        projects += 1
        total_resolved += int(float(row["resolved_count"] or 0))
        total_unresolved += int(float(row["unresolved_count"] or 0))

total_calls = total_resolved + total_unresolved
prop_resolved = total_resolved / total_calls * 100
prop_unresolved = total_unresolved / total_calls * 100

avg_resolved = total_resolved / projects
avg_unresolved = total_unresolved / projects

resolved_counts = []
unresolved_counts = []
with csv_path.open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        resolved_counts.append(int(float(row["resolved_count"] or 0)))
        unresolved_counts.append(int(float(row["unresolved_count"] or 0)))

def median(vals):
    vals = sorted(vals)
    n = len(vals)
    mid = n // 2
    if n % 2 == 1:
        return vals[mid]
    return (vals[mid - 1] + vals[mid]) / 2

med_resolved = median(resolved_counts)
med_unresolved = median(unresolved_counts)

def fmt_int(n):
    return f"{n:,}"

def fmt_avg(n):
    return f"{round(n):,}"

print("**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**\n")
print("|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |")
print("| --- | --- | --- | --- | --- | --- |")
print("|  |  |  |  |  |  |")
print(f"|  | Resolved | {fmt_int(total_resolved)} | {prop_resolved:.1f}% | {fmt_avg(avg_resolved)} | {med_resolved:.1f} |")
print(f"|  | Unresolved | {fmt_int(total_unresolved)} | {prop_unresolved:.1f}% | {fmt_avg(avg_unresolved)} | {med_unresolved:.1f} |")
PY
echo '</artisan_submit>'
