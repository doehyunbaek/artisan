#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       8 |         52 |         17.3 |          25 |         3 |
| 10 |       8 |         27 |         13.5 |          23 |         3 |
| 11 |      11 |          4 |            4 |           4 |         3 |
| 13 |      13 |          1 |            1 |           1 |         0 |
| 14 |      14 |          0 |            0 |           0 |         0 |

EOTABLE

# Section 2: Artifact download
# Download Zenodo artifact (pmsat-inference bundle)
curl -sL "https://zenodo.org/records/10423670/files/pmsat-inference-and-publication-artifacts.zip?download=1" -o /workspace/pmsat-artifacts.zip

# Section 3: Reproduction commands
# Unpack artifact
unzip -o /workspace/pmsat-artifacts.zip -d /workspace

# Run parser on the SmokeMeter learning-results to produce Table 5 reproduction
python /workspace/pmsat-inference/parse_single_run_results.py /workspace/pmsat-inference/use_cases/avl415SE_smokemeter/learning-results > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
