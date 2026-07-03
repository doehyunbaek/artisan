#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
| Merged    |       30 |              35 |
| Approved  |        1 |               1 |
| Rejected  |        1 |               1 |
| Pending   |        4 |               5 |
| **Total** |   **36** |          **42** |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L 'https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1' -o bloat-study-artifact-v1.0.zip
unzip -q bloat-study-artifact-v1.0.zip -d artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
# Ensure a clean container state before starting a new one
docker rm -f bloat-study-artifact-container 2>/dev/null || true
# Build the Docker image as instructed in the artifact
docker build -t bloat-study-artifact .
# Run the container in the background following the modified run policy
docker run -d --init --entrypoint bash \
  -v "$(pwd)/scripts:/home/user/scripts" \
  -v "$(pwd)/data:/home/user/data" \
  -v "$(pwd)/figures:/home/user/figures" \
  --name bloat-study-artifact-container \
  bloat-study-artifact -c 'sleep infinity'
# Execute the Table 3 reproduction command inside the container
docker exec bloat-study-artifact-container /bin/bash --noprofile --norc -c \
  "cd /home/user && python scripts/rq4.py data/results/qualitative_results.json --table3" \
  > /workspace/repro.txt
# Optionally stop and remove the container after use
docker rm -f bloat-study-artifact-container >/dev/null 2>&1 || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'PY'
import pathlib
from collections import OrderedDict

text = pathlib.Path('/workspace/repro.txt').read_text()
rows = {}
for line in text.splitlines():
    line = line.strip()
    if not line.startswith('|'):
        continue
    parts = [p.strip() for p in line.strip('|').split('|')]
    if not parts or parts[0] in ('PR Status', ''):
        continue
    status, prs, bd = parts[0], parts[1], parts[2]
    try:
        prs_i = int(prs)
        bd_i = int(bd)
    except ValueError:
        continue
    rows[status] = (prs_i, bd_i)

order = ['Merged', 'Approved', 'Rejected', 'Pending', 'Total']
print('**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**\n')
print('| PR status | # of PRs | # of BD removed |')
print('| --------- | -------: | --------------: |')
for status in order:
    prs_i, bd_i = rows[status]
    if status == 'Total':
        status_cell = f'**{status}**'
        prs_cell = f'**{prs_i}**'
        bd_cell = f'**{bd_i}**'
    else:
        status_cell = status
        prs_cell = str(prs_i)
        bd_cell = str(bd_i)
    print(f'| {status_cell:<9} | {prs_cell:>7} | {bd_cell:>14} |')
PY
echo '</artisan_submit>'
