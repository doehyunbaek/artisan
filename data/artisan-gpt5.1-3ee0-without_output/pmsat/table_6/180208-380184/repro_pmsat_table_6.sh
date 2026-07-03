#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       ? |        ??? |         ?.?? |          ?? |         ? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

# Build Docker image as documented
docker-compose build

# Run PMSAT on the BLE trace to produce TRACE-results for n up to 16
docker-compose run pmsat python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16

# Fix NumPy/Matplotlib compatibility and parse single-run results into table6.csv
docker-compose run pmsat bash -lc "pip install 'numpy<2' >/tmp/pip_numpy_fix.log 2>&1 && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6 > table6.csv"

# Create the reproduced markdown table by extracting the n=9 row from table6.csv
cat > /workspace/repro.txt <<'EOTREPRO'
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
EOTREPRO

# Append the formatted n=9 row derived from the generated CSV
awk -F',' 'NR==2 {printf "| %2d | %7d | %10d | %11.2f | %10d | %8d |\n", $1,$2,$3,$4,$5,$6}' table6.csv >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
