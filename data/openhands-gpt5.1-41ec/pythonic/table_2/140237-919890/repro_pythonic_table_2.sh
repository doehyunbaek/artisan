#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functiona l Corr.** | **Functiona l Wrong** | **Functiona l % Corr.** | **Procedura l Corr.** | **Procedura l Wrong** | **Procedura l % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
| Lambda    |                    112 |                     98 |                    53.33 |                    115 |                     95 |                    54.76 |
| Compr.    |                     99 |                    111 |                    47.14 |                    114 |                     96 |                    54.29 |
| MRF       |                     80 |                    130 |                    38.10 |                     85 |                    125 |                    40.48 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L 'https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1' -o ICSE2024-funcConstructs-Artifacts.zip
unzip -q -o ICSE2024-funcConstructs-Artifacts.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
sh run-analysis.sh
# Build reproduction table from generated CSV
cat > /workspace/repro.txt <<'EOT'
**Table 2: Number and percentage of correct/wrong tasks for functional constructs and their procedural alternatives**

| Construct | **Functiona l Corr.** | **Functiona l Wrong** | **Functiona l % Corr.** | **Procedura l Corr.** | **Procedura l Wrong** | **Procedura l % Corr.** |
| --------- | ---------------------: | ---------------------: | -----------------------: | ---------------------: | ---------------------: | -----------------------: |
EOT
awk -F',' 'NR==2{printf "| %-8s | %21d | %21d | %23.2f | %21d | %21d | %23.2f |\n","Lambda",$2,$3,$4,$5,$6,$7}
NR==3{printf "| %-8s | %21d | %21d | %23.2f | %21d | %21d | %23.2f |\n","Compr.",$2,$3,$4,$5,$6,$7}
NR==4{printf "| %-8s | %21d | %21d | %23.2f | %21d | %21d | %23.2f |\n","MRF",$2,$3,$4,$5,$6,$7}' results/Table-2-descriptive.csv >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
