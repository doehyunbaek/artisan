#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       7 |         12 |            3 |           6 |         4 |

EOTABLE
# Section 2: Artifact download
curl -sS -L "https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content" -o /workspace/pmsat-artifacts.zip
unzip -q /workspace/pmsat-artifacts.zip -d /workspace/artifacts
# Section 3: Reproduction commands (populate from reviewed steps)
python /workspace/artifacts/pmsat-inference/parse_single_run_results.py /workspace/artifacts/pmsat-inference/use_cases/avl_APC/learning-results > /workspace/repro.txt || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
