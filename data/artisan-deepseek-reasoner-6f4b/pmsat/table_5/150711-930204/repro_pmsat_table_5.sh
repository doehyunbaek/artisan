#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       ? |         ?? |         ??.? |          ?? |         ? |
| 10 |       ? |         ?? |         ??.? |          ?? |         ? |
| 11 |      ?? |          ? |            ? |           ? |         ? |
| 13 |      ?? |          ? |            ? |           ? |         ? |
| 14 |      ?? |          ? |            ? |           ? |         ? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
cd pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
CONTAINER_ID=$(docker run -d --init --entrypoint bash -v $(pwd):/pmsat-inference pmsat-inference-pmsat -c 'sleep infinity')
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install 'numpy<2'"
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"
# Extract the table data for n=9,10,11,13,14 and format as a markdown table
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "grep -E '^9,|^10,|^11,|^13,|^14,' /pmsat-inference/table5.csv" > /workspace/table5_filtered.csv
# Process the CSV to match expected format (remove the last column and convert to markdown)
echo "**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**" > /workspace/repro.txt
echo "" >> /workspace/repro.txt
echo "|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |" >> /workspace/repro.txt
echo "| -: | ------: | ---------: | -----------: | ----------: | --------: |" >> /workspace/repro.txt
awk -F',' '{printf "| %2s | %7s | %10s | %12s | %11s | %9s |\n", $1, $2, $3, $4, $5, $6}' /workspace/table5_filtered.csv >> /workspace/repro.txt
docker stop $CONTAINER_ID
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
