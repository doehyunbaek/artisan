#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functional — Corr.** | **Functional — Wrong** | **Functional — % Corr.** | **Procedural — Corr.** | **Procedural — Wrong** | **Procedural — % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                    53.33 |                    115 |                     95 |                    54.76 |
| Compr.    |                     99 |                    111 |                    47.14 |                    114 |                     96 |                    54.29 |
| MRF       |                     80 |                    130 |                    38.10 |                     85 |                    125 |                    40.48 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -s -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip" -o artifact.zip
unzip -q artifact.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp
docker run -v${PWD}:/data --rm -ti --name shell mdipenta/rexp:latest bash -c "cd data && R --no-save < FuncConstructs-Statistics.r" > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/ICSE2024-funcConstructs-Artifacts/results/Table-2-descriptive.csv
echo '</artisan_submit>'
