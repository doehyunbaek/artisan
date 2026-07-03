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
curl -L 'https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content' -o /workspace/bloat-study-artifact-v1.0.zip
unzip -o /workspace/bloat-study-artifact-v1.0.zip -d /workspace
# Section 3: Reproduction commands (populate from reviewed steps)
# Build the Docker image as recommended in INSTALL.md
cd /workspace/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .
# Run the container in the background following the modified run instructions
cd /workspace
docker run -d --init --entrypoint bash \
    -v /workspace/gdrosos-bloat-study-artifact-0fe2fe5/scripts:/home/user/scripts \
    -v /workspace/gdrosos-bloat-study-artifact-0fe2fe5/data:/home/user/data \
    -v /workspace/gdrosos-bloat-study-artifact-0fe2fe5/figures:/home/user/figures \
    --name bloat_container bloat-study-artifact -c 'sleep infinity'
# Execute the RQ4 script to reproduce Table 3 and capture output
cd /workspace
docker exec bloat_container /bin/bash --noprofile --norc -c "python scripts/rq4.py data/results/qualitative_results.json --table3" > /workspace/repro_raw.txt
# Extract only the ASCII table for submission
python - << 'EOPY'
import re
path = '/workspace/repro_raw.txt'
with open(path) as f:
    text = f.read()
# Capture the ASCII table between first and last +--- border
m = re.search(r"(\+[-+]+=*\+\n.*?\+[-+]+=*\+)", text, re.S)
if not m:
    table = text.strip()
else:
    table = m.group(1).strip()
with open('/workspace/repro.txt', 'w') as out:
    out.write(table + "\n")
EOPY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
