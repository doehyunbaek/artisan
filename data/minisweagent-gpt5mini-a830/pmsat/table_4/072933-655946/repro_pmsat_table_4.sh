#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       7 |         12 |            3 |           6 |         4 |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/artifact && cd /workspace/artifact
if [ ! -f pmsat-inference-and-publication-artifacts.zip ]; then
  curl -L -o pmsat-inference-and-publication-artifacts.zip 'https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip?download=1'
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Unpack artifact
unzip -q pmsat-inference-and-publication-artifacts.zip -d /workspace

# Build the docker image using docker-compose (run from the pmsat-inference folder)
cd /workspace/pmsat-inference
docker-compose build

# Start a detached pmsat container with a sleep entrypoint so we can exec into it
# Use docker-compose run -d with entrypoint bash to keep container alive
CONTAINER_ID=$(docker-compose run -d --entrypoint bash pmsat -c 'sleep infinity')
# wait a moment for container to initialize
sleep 2

# Run the mining for the APC trace (this may take a long time; respects README -nmax 13)
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /workspace/pmsat-inference && python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13"

# Find the latest generated TRACE-results folder and parse it to /workspace/repro.txt
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /workspace/pmsat-inference && LATEST=\$(ls -1d TRACE-results/* 2>/dev/null | sort | tail -n1) && python parse_single_run_results.py \"\$LATEST\" > /workspace/repro.txt || echo 'PARSE_FAILED' > /workspace/repro.txt"

# (Optional) visualize automata - commented out by default
# docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /workspace/pmsat-inference && python compile_dot_to_pdf.py \"\$LATEST\""

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission_block.txt
cat /workspace/repro.txt >> /workspace/repro_submission_block.txt
echo '</artisan_submit>' >> /workspace/repro_submission_block.txt

# Output final file location
echo "Reproduction output written to /workspace/repro.txt and /workspace/repro_submission_block.txt"
