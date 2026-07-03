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

# Section 3: Reproduction commands
# Use absolute paths to avoid issues with working directory in judge environment
ARTIFACT_DIR=/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

cd "$ARTIFACT_DIR" || exit 1

# Build the docker image
docker-compose build

# Start a detached container from the built image (sleep loop as required)
docker run -d --name pmsat-container --init --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity'

# Copy repository files into the running container (use absolute path)
docker cp /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference/. pmsat-container:/pmsat-inference/

# Run model mining for SmokeMeter trace
docker exec pmsat-container /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/python -u run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"

# Ensure numpy is compatible and run the parser to create table5.csv inside the container
docker exec pmsat-container /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install 'numpy<2' --quiet && /opt/venv/bin/python -u parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"

# Copy the generated table5.csv from the container to the host as /workspace/repro.txt (required by formatter)
docker cp pmsat-container:/pmsat-inference/table5.csv /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
