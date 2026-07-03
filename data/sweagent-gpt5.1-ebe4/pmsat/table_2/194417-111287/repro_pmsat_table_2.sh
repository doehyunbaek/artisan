#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           3 |         31 |                7.75 |                 26 |               65 |
|   4 |           4 |          5 |                1.25 |                  2 |               26 |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -d pmsat-inference ]; then
  curl -L -o artifact.zip "https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip"
  unzip -q artifact.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference
# Build docker image (no-op if already built)
docker-compose build >/dev/null 2>&1

# Start container in background (if not already running)
CID=$(docker ps --filter "name=pmsat-inference-pmsat-run" --format '{{.ID}}' | head -n 1)
if [ -z "$CID" ]; then
  CID=$(docker-compose run -d --entrypoint bash pmsat -c 'sleep infinity')
fi

# Run Table 2 reproduction commands inside container
docker exec "$CID" /bin/bash --noprofile --norc -c 'cd /pmsat-inference && python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7' >/dev/null 2>&1

# Fix numpy/matplotlib compatibility and generate table2.csv
docker exec "$CID" /bin/bash --noprofile --norc -c 'pip install "numpy<2" -U >/dev/null 2>&1 && cd /pmsat-inference && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a' > /workspace/table2.csv

# Extract only the rows for n=3 and n=4 into repro.txt
cd /workspace
{
  echo "n,n_reach,# Glitches,Mean d_g fr.,Max d_g fr.,Min d fr.,bisimilar to n="
  grep -E '^[34],' table2.csv
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Convert CSV subset to markdown table for final comparison
python - <<'PY'
import csv
from pathlib import Path

rows = list(csv.reader(Path('/workspace/repro.txt').read_text().splitlines()))
header, data = rows[0], rows[1:]

# Print as markdown
print('| ' + ' | '.join(header) + ' |')
print('| ' + ' | '.join(['---'] * len(header)) + ' |')
for r in data:
    print('| ' + ' | '.join(r) + ' |')
PY
echo '</artisan_submit>'
