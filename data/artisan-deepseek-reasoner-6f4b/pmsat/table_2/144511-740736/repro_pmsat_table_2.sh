#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           ? |         ?? |                ?.?? |                 ?? |               ?? |
|   4 |           ? |          ? |                ?.?? |                  ? |               ?? |

EOTABLE
# Section 2: Artifact download
if [ ! -d "pmsat-inference-and-publication-artifacts" ]; then
    artisan get https://zenodo.org/records/10423670
fi
# Section 3: Reproduction commands
cd pmsat-inference-and-publication-artifacts/pmsat-inference
# Clean up any existing containers
docker ps -q --filter "ancestor=pmsat-inference-pmsat" | xargs -r docker stop
docker ps -aq --filter "ancestor=pmsat-inference-pmsat" | xargs -r docker rm
# Build Docker image
docker-compose build
# Start container with volume mount
CONTAINER_ID=$(docker run -d --init -v "$(pwd):/pmsat-inference" --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity')
sleep 2
# Run model mining command
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7"
# Fix numpy version incompatibility
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install --upgrade 'numpy<2'"
# Parse results to generate table2.csv
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > table2.csv"
# Extract relevant data for n=3 and n=4 and format as markdown table
python3 <<'PYTHON_EOF'
import csv
import re
with open('table2.csv', 'r') as f:
    lines = f.readlines()
# Skip header
data_lines = [line.strip() for line in lines[1:] if line.strip()]
# Parse CSV lines (they have spaces, so we split by commas and strip)
rows = []
for line in data_lines:
    # Remove extra spaces after commas
    line = re.sub(r',\s+', ',', line)
    parts = [part.strip() for part in line.split(',')]
    if len(parts) >= 6:
        n = int(parts[0])
        if n in (3, 4):
            rows.append({
                'n': n,
                'n_reach': int(parts[1]),
                'glitches': int(parts[2]),
                'mean_dg': float(parts[3]),
                'max_dg': int(parts[4]),
                'min_d': int(parts[5])
            })
# Generate markdown table
table = """**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\\delta_g) fr. | Max (\\delta_g) fr. | Min (\\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |"""
for row in rows:
    table += f"\n| {row['n']:3d} | {row['n_reach']:11d} | {row['glitches']:10d} | {row['mean_dg']:17.2f} | {row['max_dg']:16d} | {row['min_d']:14d} |"
with open('/workspace/repro.txt', 'w') as f:
    f.write(table)
PYTHON_EOF
# Clean up container
docker stop "$CONTAINER_ID"
docker rm "$CONTAINER_ID"
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
