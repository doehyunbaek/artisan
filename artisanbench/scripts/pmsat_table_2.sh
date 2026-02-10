#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o pmsat-inference-and-publication-artifacts.zip https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content
unzip pmsat-inference-and-publication-artifacts.zip -d pmsat-inference-and-publication-artifacts
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker-compose run pmsat python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7
docker-compose run pmsat bash -lc 'pip install "numpy<2" >/dev/null 2>&1 && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a' > table2.csv
python - <<'PY'
import csv, pathlib, textwrap

csv_path = pathlib.Path("table2.csv")
rows = []
with csv_path.open() as f:
    reader = csv.DictReader(f, skipinitialspace=True)
    for row in reader:
        if row["n"] in ("3", "4"):
            rows.append(row)

header = textwrap.dedent(r"""
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
""").strip("\n")

lines = [header]
for row in rows:
    n = int(row["n"])
    n_reach = int(row["n_reach"])
    glitches = int(row["# Glitches"])
    mean = float(row["Mean d_g fr."])
    maxg = int(row["Max d_g fr."])
    mind = int(row["Min d fr."])
    lines.append(f"| {n:3d} | {n_reach:11d} | {glitches:9d} | {mean:16.2f} | {maxg:17d} | {mind:15d} |")

pathlib.Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n")
PY

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
