#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       7 |         12 |            3 |           6 |         4 |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/pmsat_artifact
curl -sL -o /workspace/pmsat.zip https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract artifact
unzip -q /workspace/pmsat.zip -d /workspace/pmsat_artifact
# Run parser on the included APC learning-results to produce table CSV
python3 /workspace/pmsat_artifact/pmsat-inference/parse_single_run_results.py /workspace/pmsat_artifact/pmsat-inference/use_cases/avl_APC/learning-results > /workspace/repro_table4.csv

# Save a human-readable reproduction output
printf "Reproduced Table 4 CSV:\n\n" > /workspace/repro.txt
cat /workspace/repro_table4.csv >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# print the reproduced table in markdown style
python3 - <<'PY'
import csv
rows=list(csv.reader(open('/workspace/repro_table4.csv')))
# print markdown header
print('|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |')
print('| -: | ------: | ---------: | -----------: | ----------: | --------: |')
# find row with n==7 and print it
for r in rows:
    if r and r[0].strip()=="7":
        print('|  '+r[0].strip()+" | "+r[1].strip()+" | "+r[2].strip()+" | "+r[3].strip()+" | "+r[4].strip()+" | "+r[5].strip()+" |")
PY

echo '</artisan_submit>'
