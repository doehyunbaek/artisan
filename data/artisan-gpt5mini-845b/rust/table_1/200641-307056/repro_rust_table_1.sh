#!/usr/bin/bash
set -euo pipefail
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Resolution accuracy.**

| Dataset Type | Tree Accuracy | Precision | Recall | F1Score |
| ------------ | ------------: | --------: | -----: | ------: |
| Random       |        ??.??% |    ??.??% | ??.??% |  ??.??% |
| Popular      |        ??.??% |    ???.??% | ??.??% |  ??.??% |
| Mostdep      |        ??.??% |    ??.??% | ??.??% |  ??.??% |

EOTABLE

# Section 2: Artifact download (required)
artisan get https://zenodo.org/records/10496086

# Section 3: Reproduction commands
# Build the docker image provided by the artifact (required to run cargo)
docker build -t cargo-ecosystem-monitor /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor

# Run the container in detached mode (replace interactive usage as requested)
CONTAINER=$(docker run -d --init --entrypoint bash -p 127.0.0.1:12345:5432 -e POSTGRES_PASSWORD="postgres" -w /app --mount type=bind,src=/workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor,target=/app cargo-ecosystem-monitor -c 'sleep infinity')

# Execute the precomputed evaluation summary inside the container to generate the real Table 1 output
docker exec "$CONTAINER" /bin/bash --noprofile --norc -c "cd /app/Code/accuracy_evaluation && unzip -o EDG_Evaluation_20220811.zip -d . >/dev/null 2>&1 || true && cargo run --bin summary_release > /app/Code/accuracy_evaluation/summary_out.txt 2>&1"

# Copy the produced summary to the expected repro location for formatting
cp /workspace/Cargo-Ecosystem-Monitor-ICSE/Cargo-Ecosystem-Monitor/Code/accuracy_evaluation/summary_out.txt /workspace/repro.txt

# Optional: stop and remove the container
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

# Section 4: Formatting (compare expected vs repro)
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
