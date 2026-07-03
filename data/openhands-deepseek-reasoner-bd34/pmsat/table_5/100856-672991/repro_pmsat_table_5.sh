#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       8 |         52 |         17.3 |          25 |         3 |
| 10 |       8 |         27 |         13.5 |          23 |         3 |
| 11 |      11 |          4 |            4 |           4 |         3 |
| 13 |      13 |          1 |            1 |           1 |         0 |
| 14 |      14 |          0 |            0 |           0 |         0 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact from Zenodo..."
curl -L -o /workspace/artifact.zip "https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content"
unzip -q /workspace/artifact.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/pmsat-inference
echo "Building Docker image..."
docker-compose build

echo "Starting container..."
CONTAINER_ID=$(docker run -d --init --entrypoint bash -v "$(pwd):/pmsat-inference" -w /pmsat-inference pmsat-inference-pmsat -c 'sleep infinity')
echo "Container ID: $CONTAINER_ID"

# Downgrade numpy to version compatible with matplotlib (numpy <2)
echo "Downgrading numpy..."
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "pip install 'numpy<2' --force-reinstall"

echo "Running PMSAT inference on SmokeMeter trace..."
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"

echo "Parsing results to CSV..."
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"

# Copy CSV out of container
docker cp $CONTAINER_ID:/pmsat-inference/table5.csv /workspace/table5.csv

# Stop container
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Output the reproduced table (formatted as markdown)
echo "**Reproduced Table 5:**"
echo ""
echo "|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |"
echo "| -: | ------: | ---------: | -----------: | ----------: | --------: |"
# Extract rows for n=9,10,11,13,14 from CSV (skip header, skip n=12)
tail -n +2 /workspace/table5.csv | while IFS=',' read -r n n_reach glitches mean max min bisim; do
    # Remove extra spaces
    n=$(echo $n | xargs)
    n_reach=$(echo $n_reach | xargs)
    glitches=$(echo $glitches | xargs)
    mean=$(echo $mean | xargs)
    max=$(echo $max | xargs)
    min=$(echo $min | xargs)
    # Check if n is 9,10,11,13,14 (skip 12)
    if [[ "$n" =~ ^(9|10|11|13|14)$ ]]; then
        printf "| %2s | %7s | %10s | %12s | %11s | %9s |\n" "$n" "$n_reach" "$glitches" "$mean" "$max" "$min"
    fi
done
echo '</artisan_submit>'