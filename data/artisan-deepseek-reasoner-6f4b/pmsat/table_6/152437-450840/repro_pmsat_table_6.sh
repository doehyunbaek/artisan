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
# Section 3: Reproduction commands
cd pmsat-inference-and-publication-artifacts/pmsat-inference
# Build Docker image (if not already built)
docker-compose build
# Start a container with volume mount that stays alive
CONTAINER_ID=$(docker run -d -v $(pwd):/pmsat-inference --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity')
# Execute the model mining command
docker exec $CONTAINER_ID bash -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16"
# Fix numpy version to be compatible with matplotlib
docker exec $CONTAINER_ID bash -c "pip install --upgrade 'numpy<2'"
# Parse results and output to file
docker exec $CONTAINER_ID bash -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6" > /workspace/repro.txt
# Stop and remove the container
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
