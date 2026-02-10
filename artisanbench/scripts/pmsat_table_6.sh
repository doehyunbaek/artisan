#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o pmsat-inference-and-publication-artifacts.zip https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content
unzip pmsat-inference-and-publication-artifacts.zip -d pmsat-inference-and-publication-artifacts
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

docker-compose build

CID=$(docker run -d --init --entrypoint bash -v "$PWD":/pmsat-inference pmsat-inference-pmsat -c 'sleep infinity')

docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/ble_nRF52832/nRF52832_moore_without_mtu_req_parsed_trace_cleaned.json -nmax 16"

docker exec "$CID" /bin/bash --noprofile --norc -c "/opt/venv/bin/pip install 'numpy<2'"

docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/bdec710c6bfabb38f70d9dc5a452f8c6 > table6.csv"

python - <<'PY'
import csv
from pathlib import Path

root = Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference")
with (root / "table6.csv").open(newline='') as f:
    rows = list(csv.DictReader(f))

row9 = next(r for r in rows if r["n"].strip() == "9")

header = (
    "**Table 6 reproduction (n=9 row)**\n\n"
    "|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |\n"
    "| -: | ------: | ---------: | -----------: | ----------: | --------: |\n"
)

line = (
    f"|  9 | {row9['n_reach'].strip():>6} | "
    f"{row9['# Glitches'].strip():>9} | "
    f"{float(row9['Mean d_g fr.']):9.2f} | "
    f"{int(row9['Max d_g fr.']):10d} | "
    f"{int(row9['Min d fr.']):8d} |\n"
)

Path("/workspace/repro.txt").write_text(header + line)
PY

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
