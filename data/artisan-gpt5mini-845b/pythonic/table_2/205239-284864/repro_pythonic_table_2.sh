#!/usr/bin/bash
set -euo pipefail
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    ??? |                     ?? |                    ??.?? |                    ??? |                     ?? |                    ??.?? |
| Compr.    |                     ?? |                    ??? |                    ??.?? |                    ??? |                     ?? |                    ??.?? |
| MRF       |                     ?? |                    ??? |                    ??.?? |                     ?? |                    ??? |                    ??.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands
# Pull the Docker image
docker pull mdipenta/rexp:latest

# Start a detached container (sleep infinity) to run the analysis
docker run -d --init --entrypoint bash --name func_rexp_temp mdipenta/rexp:latest -c 'sleep infinity'

# Copy the unpacked artifact into the container
docker cp ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts func_rexp_temp:/data

# Execute the R analysis script inside the container to produce results
docker exec func_rexp_temp /bin/bash --noprofile --norc -c "cd /data/ICSE2024-funcConstructs-Artifacts && R --no-save < FuncConstructs-Statistics.r"

# Copy the resulting Table-2-descriptive.csv out as the reproduction output
docker cp func_rexp_temp:/data/ICSE2024-funcConstructs-Artifacts/results/Table-2-descriptive.csv /workspace/repro.txt

# Clean up the container
docker rm -f func_rexp_temp || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
