#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       9 |        106 |         8.83 |          16 |         7 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker-compose run --rm pmsat bash -lc "python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16 && /opt/venv/bin/pip install 'numpy<2' && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6 > table6.csv"
row=$(awk -F',' 'NR==2{
  for(i=1;i<=6;i++){
    gsub(/^[ \t]+|[ \t]+$/,"",$i)
  }
  printf "|  %s |       %s |        %s |         %s |          %s |         %s |\n",$1,$2,$3,$4,$5,$6
}' table6.csv)
{
  echo '**Table 6: Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**'
  echo
  echo '|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |'
  echo '| -: | ------: | ---------: | -----------: | ----------: | --------: |'
  printf '%s\n' "$row"
} > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
