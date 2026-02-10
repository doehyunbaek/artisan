#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o pmsat-inference-and-publication-artifacts.zip https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content
unzip pmsat-inference-and-publication-artifacts.zip -d pmsat-inference-and-publication-artifacts
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker-compose run pmsat python parse_all_results_timeouts.py benchmarkingset-rc2-results > table3.csv
python <<'PY'
import math
import pathlib

root = pathlib.Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference")
with root.joinpath("table3.csv").open() as f:
    header = f.readline().strip().split(",")
    counts_line = f.readline().strip().split(",")

# Extract n values and timeout counts
ns = [int(x) for x in header[1:] if x.strip()]
counts = [int(float(x)) for x in counts_line[1:] if x.strip()]

# Only n = 8..17 are needed for the table
selected_ns = list(range(8, 18))
indices = [ns.index(n) for n in selected_ns]
selected_counts = [counts[i] for i in indices]

denom = 400.0

def round_half_up(value: float, ndigits: int) -> float:
    m = 10 ** ndigits
    return math.floor(value * m + 0.5) / m

pcts = []
for n, c in zip(selected_ns, selected_counts):
    perc = c / denom * 100.0
    if n <= 15:
        r = round_half_up(perc, 1)
        pcts.append(f"{r:.1f}")
    else:
        r = int(math.floor(perc + 0.5))
        pcts.append(str(r))

header_row = "| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |"
sep_row    = "| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |"
pct_row = "| timeout % | " + " | ".join(pcts[:6]) + " | " + " | ".join(pcts[6:8]) + " | " + " | ".join(pcts[8:]) + " |"

with open("/workspace/repro.txt", "w") as out:
    out.write("**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**\n\n")
    out.write(header_row + "\n")
    out.write(sep_row + "\n")
    out.write(pct_row + "\n")
PY

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
