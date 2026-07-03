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
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

# Build the Docker image for the prepared environment
docker-compose build

# Run PMSAT on the APC trace, then fix NumPy and generate table4.csv inside the container
docker-compose run pmsat bash -lc "python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13 && python -m pip install 'numpy<2' && python parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409 > table4.csv"

# Parse the generated CSV to extract the row for n=7 and render the reproduction Markdown table
python - <<'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference/table4.csv")
with csv_path.open(newline='') as f:
    reader = csv.DictReader(f)
    row_7 = None
    for row in reader:
        if row["n"].strip() == "7":
            row_7 = row
            break

if row_7 is None:
    raise SystemExit("Row for n=7 not found in table4.csv")

n_reach = row_7["n_reach"].strip()
glitches = row_7["# Glitches"].strip()
mean_dg = row_7["Mean d_g fr."].strip()
max_dg = row_7["Max d_g fr."].strip()
min_d = row_7["Min d fr."].strip()

repro = f"""**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       {n_reach} |         {glitches} |            {mean_dg} |           {max_dg} |         {min_d} |
"""

Path("/workspace/repro.txt").write_text(repro)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
