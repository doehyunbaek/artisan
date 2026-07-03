#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       ? |         ?? |            ? |           ? |         ? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
cd pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker run -d --init --name pmsat-container -v $(pwd):/pmsat-inference pmsat-inference-pmsat sleep infinity
docker exec pmsat-container /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13"
docker exec pmsat-container /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install --upgrade numpy==1.24.3"
# Run parse script and capture output, then extract n=7 row
docker exec pmsat-container /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409" > /workspace/parse_output.txt 2>&1
# Extract the line for n=7 from the output (the line starting with 7,)
LINE=$(grep '^7,' /workspace/parse_output.txt)
if [ -z "$LINE" ]; then
    # If not found, try with spaces after comma
    LINE=$(grep '^7, *' /workspace/parse_output.txt)
fi
# Parse the line: format is "7,7      ,12        ,3.0         ,6          ,4        ,7"
# We need to extract each column, removing extra spaces.
# Use awk to split by commas and remove whitespace.
N=7
N_REACH=$(echo "$LINE" | awk -F',' '{gsub(/ /, "", $2); print $2}')
GLITCHES=$(echo "$LINE" | awk -F',' '{gsub(/ /, "", $3); print $3}')
MEAN=$(echo "$LINE" | awk -F',' '{gsub(/ /, "", $4); print $4}')
MAX=$(echo "$LINE" | awk -F',' '{gsub(/ /, "", $5); print $5}')
MIN=$(echo "$LINE" | awk -F',' '{gsub(/ /, "", $6); print $6}')
# Write the reproduction table to /workspace/repro.txt
cat > /workspace/repro.txt <<EOREPRO
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  $N |       $N_REACH |         $GLITCHES |            $MEAN |           $MAX |         $MIN |

EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
