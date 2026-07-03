#!/usr/bin/bash
set -e

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           3 |         31 |                7.75 |                 26 |               65 |
|   4 |           4 |          5 |                1.25 |                  2 |               26 |

EOTABLE

# Section 2: Artifact download
cd /workspace
curl -L "https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip" -o pmsat-inference-and-publication-artifacts.zip
unzip -o -d /workspace /workspace/pmsat-inference-and-publication-artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)

# Build Docker image as described in README
cd /workspace/pmsat-inference
docker-compose build

# Ensure a clean container for this reproduction run
docker rm -f pmsat_table_2 >/dev/null 2>&1 || true

# Start long-running container from the built image
docker run -d --init --entrypoint bash \
  -v /workspace/pmsat-inference:/pmsat-inference \
  --name pmsat_table_2 \
  pmsat-inference-pmsat -c 'sleep infinity'

# Fix NumPy/Matplotlib compatibility in the container
docker exec pmsat_table_2 /bin/bash --noprofile --norc -c "source /opt/venv/bin/activate && pip install 'numpy<2'"

# Mine models from ping-pong example traces (Figure/Table 2 first command)
docker exec pmsat_table_2 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7"

# Parse single-run results to produce table2.csv (Figure/Table 2 second command)
docker exec pmsat_table_2 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > table2.csv"

# Format the reproduced results (n=3,4 rows) into /workspace/repro.txt as a Markdown table
python - <<'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/pmsat-inference/table2.csv")
rows = []
with csv_path.open(newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row["n"] in ("3", "4"):
            rows.append(row)

header = "| (n) | (n_{reach}) | # Glitches | Mean (\\delta_g) fr. | Max (\\delta_g) fr. | Min (\\delta) fr. |"
sep    = "| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |"

lines = [header, sep]
for r in rows:
    lines.append(
        f"| {r['n'].strip()} | {r['n_reach'].strip()} | {r['# Glitches'].strip()} | "
        f"{r['Mean d_g fr.'].strip()} | {r['Max d_g fr.'].strip()} | {r['Min d fr.'].strip()} |"
    )

Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
