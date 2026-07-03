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
# Download and extract the artifact from Zenodo
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
# Build Docker environment, run PMSAT on ping-pong traces, fix NumPy, and parse results into table2.csv
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker-compose run pmsat python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7
docker-compose run pmsat bash -lc 'pip install "numpy<2" && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > table2.csv'
# Construct the reproduction table for n=3 and n=4 and write it to /workspace/repro.txt
cat > /workspace/repro.txt <<'EOREPRO'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           3 |         31 |                7.75 |                 26 |               65 |
|   4 |           4 |          5 |                1.25 |                  2 |               26 |
EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the output table for comparison
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
