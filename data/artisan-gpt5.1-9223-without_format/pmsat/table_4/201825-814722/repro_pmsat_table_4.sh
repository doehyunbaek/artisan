#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       7 |         12 |          3.0 |           6 |         4 |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference || exit 1

# Build the Docker image as specified in the README
docker-compose build

# Start a long-lived container with the repository bind-mounted
CID=$(docker run -d --init --entrypoint bash -v "$(pwd):/pmsat-inference" pmsat-inference-pmsat -c 'sleep infinity')

# Mine models from the APC trace (produces TRACE-results/cec0073ace4...)
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13"

# Fix NumPy version inside the container to avoid the NumPy 2.x binary-compat issue
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && pip install 'numpy<2'"

# Parse the single-run results to produce table4.csv
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409 > table4.csv"

# Stop the helper container
docker stop "$CID" >/dev/null

# Extract header + n=7 row into the canonical reproduction output file
awk -F',' 'NR==1 || $1==7' table4.csv > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - <<'PY'
import csv, pathlib

path = pathlib.Path("/workspace/repro.txt")
with path.open() as f:
    rows = list(csv.reader(f))

if len(rows) < 2:
    raise SystemExit("repro.txt does not contain expected data")

hdr, row = rows[0], rows[1]

n = int(row[0])
n_reach = int(row[1])
glitches = int(row[2])
mean_dg = float(row[3])
max_dg = int(row[4])
min_d = int(row[5])

print("**Reproduced Table 4 (APC, n=7 row)**")
print()
print("|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |")
print("| -: | ------: | ---------: | -----------: | ----------: | --------: |")
print(f"| {n:2d} | {n_reach:7d} | {glitches:9d} | {mean_dg:11.1f} | {max_dg:10d} | {min_d:8d} |")
PY
echo '</artisan_submit>'
