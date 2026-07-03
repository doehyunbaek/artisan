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
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
set -e
ARTIFACT_DIR=/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
cd "$ARTIFACT_DIR"

# Build the Docker environment (as in README)
docker-compose build

# Ensure no stale container, then start one with the repo mounted
docker rm -f pmsat_run || true
docker run -d --init --name pmsat_run -v "$ARTIFACT_DIR":/pmsat-inference --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity'

# Run the mining command (use the venv python)
docker exec pmsat_run /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7"

# Downgrade numpy inside venv if needed (fixes matplotlib/numpy incompatibility) and parse results to table2.csv
docker exec pmsat_run /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install --no-cache-dir 'numpy<2' && /opt/venv/bin/python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > table2.csv"

# Copy the produced table to the workspace repro file
# Prefer docker cp; if that fails fallback to the mounted host file
docker cp pmsat_run:/pmsat-inference/table2.csv /workspace/repro.txt || cp "$ARTIFACT_DIR/table2.csv" /workspace/repro.txt || true

# Clean up container
docker rm -f pmsat_run || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
