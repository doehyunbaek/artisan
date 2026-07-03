#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | 0.5 | 0.3 | 0.5 | 1.5 | 3.5 | 5.8 | 10.3 | 17.5 | 27 | 33 |

EOTABLE
# Section 2: Artifact download
if [ ! -d /workspace/pmsat-inference ]; then
  curl -L -o /workspace/pmsat-artifacts.zip 'https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip?download=1'
  unzip -q /workspace/pmsat-artifacts.zip -d /workspace
fi
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference
# Build the Docker image for the PMSAT environment
docker-compose build
# Generate raw timeout statistics for benchmarkingset-rc2-results
docker-compose run --rm pmsat python parse_all_results_timeouts.py benchmarkingset-rc2-results > table3.csv
# Derive the Table 3 percentages from timeout counts
python - << 'PY'
import csv
import math
from pathlib import Path

csv_path = Path('/workspace/pmsat-inference/table3.csv')
rows = list(csv.reader(csv_path.open(), skipinitialspace=True))

header = rows[0]
indices = {}
for idx, val in enumerate(header):
    val = val.strip()
    if not val or val == 'n':
        continue
    try:
        n = int(val)
    except ValueError:
        continue
    if 8 <= n <= 17:
        indices[n] = idx

timeouts_row = next(r for r in rows if r and r[0].strip().startswith('#'))

timeouts = {n: int(timeouts_row[idx]) for n, idx in indices.items()}

def round_half_up(x: float) -> float:
    return math.floor(x * 10 + 0.5) / 10.0

ordered_ns = list(range(8, 18))
values = []
for n in ordered_ns:
    t = timeouts[n]
    perc = t * 100.0 / 400.0
    r = round_half_up(perc)
    if abs(r - round(r)) < 1e-9:
        s = str(int(round(r)))
    else:
        s = f"{r:.1f}"
    values.append(s)

table = f"""**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**\n\n| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |\n| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |\n| timeout % | {values[0]} | {values[1]} | {values[2]} | {values[3]} | {values[4]} | {values[5]} | {values[6]} | {values[7]} | {values[8]} | {values[9]} |\n\n"""
Path('/workspace/repro.txt').write_text(table)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
