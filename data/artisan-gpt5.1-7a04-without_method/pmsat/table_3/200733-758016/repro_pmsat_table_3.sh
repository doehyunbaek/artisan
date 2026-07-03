#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | ?.? | ?.? | ?.? | ?.? | ?.? | ?.? | ??.? | ??.? | ?? | ?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker-compose run pmsat python parse_all_results_timeouts.py benchmarkingset-rc2-results > table3.csv

python - <<'PY'
import pathlib

base = pathlib.Path("/workspace/pmsat-inference-and-publication-artifacts/pmsat-inference")
csv_path = base / "table3.csv"

text = csv_path.read_text().strip().splitlines()
header = [x.strip() for x in text[0].split(",")]
vals = [x.strip() for x in text[2].split(",")]

n_to_frac = {}
for h, v in zip(header[1:], vals[1:]):
    if not h or not v:
        continue
    n = int(h)
    frac = float(v)
    n_to_frac[n] = frac

ns = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
percentages = [f"{n_to_frac[n]*100:.1f}" for n in ns]

lines_out = [
    "**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**",
    "",
    "| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |",
    "| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |",
    "| timeout % | " + " | ".join(percentages) + " |",
]

out_path = pathlib.Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines_out) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
