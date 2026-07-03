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
mkdir -p /workspace/bloat-artifact
cd /workspace
curl -L "https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content" -o bloat-study-artifact-v1.0.zip
unzip -q -o bloat-study-artifact-v1.0.zip -d /workspace/bloat-artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/bloat-artifact/gdrosos-bloat-study-artifact-0fe2fe5
if ! docker image inspect bloat-study-artifact >/dev/null 2>&1; then
  docker build -t bloat-study-artifact .
fi
docker rm -f bloat-table2 >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash \
  -v $(pwd)/scripts:/home/user/scripts \
  -v $(pwd)/data:/home/user/data \
  -v $(pwd)/figures:/home/user/figures \
  --name bloat-table2 \
  bloat-study-artifact -c 'sleep infinity'
docker exec bloat-table2 /bin/bash --noprofile --norc -c "cd /home/user && python scripts/descriptives/evaluation.py -csv data/results/rq1a.csv" > /workspace/repro.txt
docker rm -f bloat-table2 >/dev/null 2>&1 || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'PY'
import pathlib
import math

text = pathlib.Path('/workspace/repro.txt').read_text().strip().splitlines()
header, *rows = text

results = {}
for line in rows:
    parts = line.split()
    name = parts[0]
    aggregate = int(parts[1])
    proportion = float(parts[2])
    average = float(parts[3])
    median = float(parts[4])
    results[name] = {
        'aggregate': f"{aggregate:,}",
        'proportion': f"{proportion:.1f}%",
        'average': f"{round(average):,}",
        'median': f"{median:.1f}",
    }

resolved = results['Resolved']
unresolved = results['Unresolved']

print('**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**')
print()
print('|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |')
print('| --- | --- | --- | --- | --- | --- |')
print('|  |  |  |  |  |  |')
print(f"|  | Resolved | {resolved['aggregate']} | {resolved['proportion']} | {resolved['average']} | {resolved['median']} |")
print(f"|  | Unresolved | {unresolved['aggregate']} | {unresolved['proportion']} | {unresolved['average']} | {unresolved['median']} |")
PY
echo '</artisan_submit>'
