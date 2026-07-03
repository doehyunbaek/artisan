#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md << 'EOTABLE'
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       9 |        106 |         8.83 |          16 |         7 |
EOTABLE

# Choose Python interpreter for helper invocations
if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
else
  PYTHON=python
fi

# Section 2: Artifact download (Zenodo 10423670)
# Use the previously created helper driver to fetch and unpack the artifact.
if [ -x /workspace/repro_pmsat_table_6_driver.py ]; then
  "$PYTHON" /workspace/repro_pmsat_table_6_driver.py download
fi

ARTIFACT_ROOT="/workspace/artifact_10423670"
REPO_DIR="$ARTIFACT_ROOT/extracted/pmsat-inference"

# Section 3: Reproduction commands
# 3.1 Build Docker environment (as per README)
cd "$REPO_DIR"
docker-compose build

# 3.2 Run PMSAT on the BLE trace to produce TRACE-results for Table 6
docker-compose run pmsat python run_pmsat_on_traces.py \
  use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json \
  -nmax 16

# 3.3 Downgrade NumPy inside the container and parse the single-run results to CSV.
# The pip output will be mixed with the CSV header; we will filter the CSV row later.
docker-compose run pmsat bash -lc "pip install 'numpy<2' && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6" > table6.csv

# 3.4 Extract the n = 9 row from table6.csv and format the reproduction table to /workspace/repro.txt
row="$(grep '^9,' table6.csv | head -n 1 || true)"

# If for some reason the row is missing, fall back to an empty repro file.
if [ -z "$row" ]; then
  echo "Failed to locate n=9 row in table6.csv" >&2
  : > /workspace/repro.txt
else
  IFS=',' read -r n n_reach glitches mean_dg max_dg min_d _bisim <<< "$row"

  trim() {
    # Trim leading/trailing whitespace
    printf '%s' "$1" | xargs
  }

  n="$(trim "$n")"
  n_reach="$(trim "$n_reach")"
  glitches="$(trim "$glitches")"
  mean_dg="$(trim "$mean_dg")"
  max_dg="$(trim "$max_dg")"
  min_d="$(trim "$min_d")"

  cat > /workspace/repro.txt <<EOTABLE
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
| $(printf '%2d' "$n") | $(printf '%7d' "$n_reach") | $(printf '%9d' "$glitches") | $(printf '%11s' "$mean_dg") | $(printf '%10s' "$max_dg") | $(printf '%8s' "$min_d") |
EOTABLE
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
