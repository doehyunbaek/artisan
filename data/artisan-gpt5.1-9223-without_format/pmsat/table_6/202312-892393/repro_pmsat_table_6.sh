#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       9 |        106 |         8.83 |          16 |         7 |
EOTABLE

# Section 2: Artifact download
cd /workspace
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

# Build the Docker image (idempotent)
docker-compose build

# Start a long-lived container with the repository mounted at /pmsat-inference
CID=$(docker run -d --init --entrypoint bash -v "$PWD":/pmsat-inference pmsat-inference-pmsat -c 'sleep infinity')

# Run PMSAT on the BLE trace to generate TRACE-results
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16"

# Fix NumPy version inside the container to avoid binary incompatibility with matplotlib
docker exec "$CID" /bin/bash --noprofile --norc -c "/opt/venv/bin/pip install 'numpy<2'"

# Generate table6.csv from the BLE TRACE-results
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6 > table6.csv"

# Extract the n=9 row from table6.csv and format it as a markdown table into /workspace/repro.txt
python - <<'PY'
import csv
from pathlib import Path

root = Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference")
with (root / "table6.csv").open(newline='') as f:
    rows = list(csv.DictReader(f))

row9 = next(r for r in rows if r["n"].strip() == "9")

header = (
    "**Table 6 reproduction (n=9 row)**\n\n"
    "|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |\n"
    "| -: | ------: | ---------: | -----------: | ----------: | --------: |\n"
)

line = (
    f"|  9 | {row9['n_reach'].strip():>6} | "
    f"{row9['# Glitches'].strip():>9} | "
    f"{float(row9['Mean d_g fr.']):9.2f} | "
    f"{int(row9['Max d_g fr.']):10d} | "
    f"{int(row9['Min d fr.']):8d} |\n"
)

Path("/workspace/repro.txt").write_text(header + line)
PY

# Clean up the container
docker rm -f "$CID" >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
