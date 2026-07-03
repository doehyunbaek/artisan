#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           3 |         31 |                7.75 |                 26 |               65 |
|   4 |           4 |          5 |                1.25 |                  2 |               26 |

EOTABLE

# Section 2: Artifact download
curl -L -s -o /workspace/pmsat-inference-and-publication-artifacts.zip 'https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip?download=1'
unzip -q /workspace/pmsat-inference-and-publication-artifacts.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/pmsat-inference

# Build Docker image as documented
docker-compose build

# Ensure no leftover container, then start container with the repository mounted
docker rm -f pmsat_container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name pmsat_container -v /workspace/artifact/pmsat-inference:/pmsat-inference pmsat-inference-pmsat -c 'sleep infinity'

# Run the ping-pong experiment (this creates TRACE-results/... with the run hash)
docker exec pmsat_container /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7"

# Fix potential numpy/matplotlib binary incompatibility (as done interactively) and parse results
docker exec pmsat_container /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install --no-cache-dir 'numpy<2'"
docker exec pmsat_container /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > /pmsat-inference/table2.csv"

# Copy the produced CSV to the required output path
cp /workspace/artifact/pmsat-inference/table2.csv /workspace/repro.txt 2>/dev/null || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
if [ -s /workspace/repro.txt ]; then
  cat /workspace/repro.txt
else
  echo "ERROR: /workspace/repro.txt not found or empty. Check the reproduction steps in the script."
fi
echo '</artisan_submit>'
