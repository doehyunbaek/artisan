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
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

# Build the Docker image as in the README
docker-compose build

# Ensure a clean container name
docker rm -f pmsat_table5 || true

# Start a long-running container with the repository mounted at /pmsat-inference
docker run -d --init --name pmsat_table5 -v "$(pwd)":/pmsat-inference --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity'

# Run PMSAT inference on the SmokeMeter trace (nmax 14)
docker exec pmsat_table5 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"

# Fix NumPy compatibility inside the container for matplotlib / parse_single_run_results
docker exec pmsat_table5 /bin/bash --noprofile --norc -c "source /opt/venv/bin/activate && pip install 'numpy<2' --force-reinstall"

# Parse the single run results into table5.csv (as documented in README)
docker exec pmsat_table5 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"

# Copy the generated CSV to a stable workspace location
cp /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference/table5.csv /workspace/table5.csv

# Format the reproduction table into /workspace/repro.txt
cd /workspace
{
  cat <<'EOTABLE2'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
EOTABLE2
  # Use the CSV to fill in the numeric values, skipping n=12, and normalize Mean δ_g fr. to drop trailing ".0"
  awk -F',' 'NR>1{
    # Strip spaces
    for(i=1;i<=6;i++){ gsub(/ /,"",$i) }
    # Skip the n=12 row (not shown in the paper table)
    if($1==12) next
    mean=$4
    sub(/\.0$/,"",mean)
    printf("| %2d | %7s | %9s | %11s | %10s | %8s |\n",$1,$2,$3,mean,$5,$6)
  }' table5.csv
} > /workspace/repro.txt

# Clean up the container
docker rm -f pmsat_table5 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
