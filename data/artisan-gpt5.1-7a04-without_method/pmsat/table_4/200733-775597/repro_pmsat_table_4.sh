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
# Build the Docker image in the artifact repository
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
# Run PMSAT on the APC trace, fix NumPy/Matplotlib ABI issues, and generate table4.csv inside the container
docker-compose run -T pmsat bash -lc "pip install 'numpy<2' 'matplotlib==3.6.2' --force-reinstall && python run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13 && python parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409 > table4.csv"
# Extract the row for n=7 from table4.csv and write the reproduced markdown table to /workspace/repro.txt
python - <<'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference/table4.csv")
with csv_path.open(newline="") as f:
    rows = list(csv.DictReader(f))

row = next(r for r in rows if r["n"].strip() == "7")

out_path = Path("/workspace/repro.txt")
with out_path.open("w", encoding="utf-8") as f:
    f.write("**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**\n\n")
    f.write("|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |\n")
    f.write("| -: | ------: | ---------: | -----------: | ----------: | --------: |\n")
    f.write(f"| {row['n'].strip()} | {row['n_reach'].strip()} | {row['# Glitches'].strip()} | {row['Mean d_g fr.'].strip()} | {row['Max d_g fr.'].strip()} | {row['Min d fr.'].strip()} |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
