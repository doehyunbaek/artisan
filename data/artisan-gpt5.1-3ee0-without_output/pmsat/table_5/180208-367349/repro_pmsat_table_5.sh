#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       ? |         ?? |         ??.? |          ?? |         ? |
| 10 |       ? |         ?? |         ??.? |          ?? |         ? |
| 11 |      ?? |          ? |            ? |           ? |         ? |
| 13 |      ?? |          ? |            ? |           ? |         ? |
| 14 |      ?? |          ? |            ? |           ? |         ? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
# Build the Docker image as documented
docker-compose build
# Start a long-running container from the built image with the repo mounted
docker run -d --init --name pmsat_table5_runner -v /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference:/pmsat-inference -w /pmsat-inference pmsat-inference-pmsat bash -c 'sleep infinity'
# Mine models from the SmokeMeter trace (nmax = 14)
docker exec pmsat_table5_runner /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"
# Fix NumPy/Matplotlib compatibility inside the venv
docker exec pmsat_table5_runner /bin/bash --noprofile --norc -c ". /opt/venv/bin/activate && pip install 'numpy<2'"
# Generate table5.csv from the TRACE-results
docker exec pmsat_table5_runner /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"
# Convert table5.csv into the final Markdown table for reproduction
python - <<'EOPY'
import csv
import pathlib

in_path = pathlib.Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference/table5.csv")
rows = []
with in_path.open() as f:
    reader = csv.DictReader(f)
    for r in reader:
        n = int(r["n"])
        if n in (9, 10, 11, 13, 14):
            rows.append({
                "n": n,
                "n_reach": int(r["n_reach"]),
                "# Glitches": int(r["# Glitches"]),
                "Mean δ_g fr.": float(r["Mean d_g fr."]),
                "Max δ_g fr.": int(r["Max d_g fr."]),
                "Min δ fr.": int(r["Min d fr."]),
            })

order = [9, 10, 11, 13, 14]
rows.sort(key=lambda x: order.index(x["n"]))

out = pathlib.Path("/workspace/repro.txt")
with out.open("w") as f:
    f.write("**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**\n\n")
    f.write("|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |\n")
    f.write("| -: | ------: | ---------: | -----------: | ----------: | --------: |\n")
    for r in rows:
        f.write(f"| {r['n']:2d} | {r['n_reach']:7d} | {r['# Glitches']:9d} | {r['Mean δ_g fr.']:11.1f} | {r['Max δ_g fr.']:10d} | {r['Min δ fr.']:8d} |\n")
EOPY
# Clean up the helper container
docker rm -f pmsat_table5_runner || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
