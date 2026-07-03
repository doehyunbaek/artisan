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
# Build Docker image as documented
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build

# Start a long-running container from the built image following the docker guidelines
CID=$(docker run -d --init --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity')

# Mine models from ping pong example traces
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7"

# Ensure NumPy is compatible with matplotlib in the container
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && pip install 'numpy<2'"

# Read from results and pipe Table 2 to CSV
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > table2.csv"

# Copy the generated CSV back to the workspace
docker cp "$CID":/pmsat-inference/table2.csv /workspace/table2.csv || true

# Stop the container (ignore errors if already stopped)
docker stop "$CID" || true

# Programmatically create the reproduction table from /workspace/table2.csv
python - <<'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/table2.csv")
rows_by_n = {}

with csv_path.open(newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        n = row["n"].strip()
        if n in {"3", "4"}:
            rows_by_n[int(n)] = row

def sval(row, key):
    return row[key].strip()

lines = []
lines.append("**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**")
lines.append("")
lines.append("| (n) | (n_{reach}) | # Glitches | Mean (\\delta_g) fr. | Max (\\delta_g) fr. | Min (\\delta) fr. |")
lines.append("| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |")

for n in (3, 4):
    row = rows_by_n[n]
    n_reach   = int(sval(row, "n_reach"))
    glitches  = int(sval(row, "# Glitches"))
    mean_dg   = float(sval(row, "Mean d_g fr."))
    max_dg    = int(sval(row, "Max d_g fr."))
    min_d     = int(sval(row, "Min d fr."))
    lines.append(
        f"| {n:3d} | {n_reach:11d} | {glitches:9d} | {mean_dg:16.2f} | {max_dg:17d} | {min_d:15d} |"
    )

Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
