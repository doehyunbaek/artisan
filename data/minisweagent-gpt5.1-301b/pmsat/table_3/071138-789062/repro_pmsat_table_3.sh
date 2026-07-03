#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | 0.5 | 0.3 | 0.5 | 1.5 | 3.5 | 5.8 | 10.3 | 17.5 | 27 | 33 |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f pmsat-inference-and-publication-artifacts.zip ]; then
  curl -L -o pmsat-inference-and-publication-artifacts.zip \
    https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip
fi
if [ ! -d pmsat-inference ]; then
  unzip -q pmsat-inference-and-publication-artifacts.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference
# Recompute timeout statistics for the large benchmarking set (creates/overwrites table3.csv)
python parse_all_results_timeouts.py benchmarkingset-rc2-results > table3.csv

# Convert table3.csv into the markdown table format and write to /workspace/repro.txt
python - "$PWD/table3.csv" >/workspace/repro.txt <<'PYCODE'
import csv, sys, pathlib

csv_path = pathlib.Path(sys.argv[1])
with csv_path.open(newline="") as f:
    rows = list(csv.reader(f))

# Expect header like: n,8,9,10,11,12,13,14,15,16,17
# and a data row with percentages
header = rows[0]
data = rows[1]

# Build markdown table matching expected.md
n_header = header[0]
ns = header[1:]
values = data[1:]

# First line: title
print("**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**")
print()
# Header row
print("| n         | " + " | ".join(f"{n:>3}" for n in ns) + " |")
# Alignment row
align = []
for n in ns:
    width = max(2, len(str(n)))
    dashes = "-" * width
    align.append(f"{dashes}:")
print("| --------- | " + " | ".join(align) + " |")
# Data row
print("| timeout % | " + " | ".join(v for v in values) + " |")
PYCODE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
