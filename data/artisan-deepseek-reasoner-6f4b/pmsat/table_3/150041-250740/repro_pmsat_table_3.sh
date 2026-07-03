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
cd pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
# Start a container, run the command, then stop it
docker-compose run --rm pmsat /bin/bash -c "python parse_all_results_timeouts.py benchmarkingset-rc2-results" > /workspace/repro_raw.txt 2>&1
# Extract the relevant lines and format as a table
grep -E "^% t\.o\." /workspace/repro_raw.txt | sed -E 's/^% t\.o\. ,//g' | tr -d ' ' > /workspace/percent_line.txt
# The line looks like: 0.0,0.0,0.0,0.0,0.0,0.0,0.00501,0.00251,0.00501,0.015,0.0351,0.0576,0.103,0.175,0.271,0.331
# We need columns 8-17 (skip first 6). Convert to percentages and format.
python3 -c "
import sys
with open('/workspace/percent_line.txt', 'r') as f:
    line = f.read().strip()
vals = line.split(',')
# indices 6 to 15 correspond to n=8 to 17 (0-indexed)
selected = vals[6:16]
# Convert to percentages
percents = []
for i, v in enumerate(selected):
    n = i + 8
    p = float(v) * 100
    if n <= 13:
        percents.append(f'{p:.1f}')
    elif n <= 15:
        percents.append(f'{p:.1f}')
    else:
        percents.append(f'{int(round(p))}')
# Create markdown table
table = '''**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |'''.format(*percents)
with open('/workspace/repro.txt', 'w') as out:
    out.write(table)
" 2>/dev/null
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
