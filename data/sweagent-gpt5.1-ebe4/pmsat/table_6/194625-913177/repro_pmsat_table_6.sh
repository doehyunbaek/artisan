#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
cd /workspace && cat > repro_pmsat_table_6.sh <<'EOF'
#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
3 and dominant ;33mm transitions.**

echo EXITCODESTART$?EXITCODEEND3 fr. | Min ;33mm fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       9 |        106 |         8.83 |          16 |         7 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip -o artifact.zip
unzip -q artifact.zip -d artifact

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/pmsat-inference
# Build and start docker environment
docker-compose build
# Start container in background with long-running sleep
CONTAINER_NAME=pmsat_container_table6
docker-compose run -d --name ${CONTAINER_NAME} --entrypoint bash pmsat -c 'sleep infinity'
# Run mining for BLE use case
docker exec ${CONTAINER_NAME} /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16"
# Fix numpy / matplotlib compatibility as encountered during reproduction
docker exec ${CONTAINER_NAME} /bin/bash --noprofile --norc -c "source /opt/venv/bin/activate && pip install 'numpy<2'"
# Generate Table 6 CSV from the single run results
docker exec ${CONTAINER_NAME} /bin/bash --noprofile --norc -c "cd /pmsat-inference && source /opt/venv/bin/activate && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6 > table6.csv"
# Copy reproduction results back to /workspace and extract the relevant row (n=9) into repro.txt
cp /workspace/artifact/pmsat-inference/table6.csv /workspace/
awk 'NR==1 || $1=="9"' /workspace/table6.csv > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Convert the CSV subset in repro.txt to the markdown table format expected
python - << 'PYEOF'
import csv
from io import StringIO

with open('/workspace/repro.txt', 'r') as f:
    data = list(csv.reader(f))

header = data[0]
row = data[1]

print("**Table 6 (reproduced): Statistics of inferring the nRF52832 BLE chip with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**\n")
print("|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |")
print("| -: | ------: | ---------: | -----------: | ----------: | --------: |")
print(f"| {int(row[0]):2d} | {int(row[1]):7d} | {int(row[2]):9d} | {float(row[3]):11.2f} | {int(row[4]):10d} | {int(row[5]):8d} |")
PYEOF
echo '</artisan_submit>'
