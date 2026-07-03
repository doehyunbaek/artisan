#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
| timeout % | 0.5 | 0.3 | 0.5 | 1.5 | 3.5 | 5.8 | 10.3 | 17.5 | 27 | 33 |

EOTABLE

# Section 2: Artifact download
curl -s https://zenodo.org/api/records/10423670 -o /workspace/zenodo.json
curl -L -o /workspace/pmsat-inference-and-publication-artifacts.zip "https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content"

# Section 3: Reproduction commands (populate from reviewed steps)
# extract archive, run timeout parser and save output to /workspace/repro.txt
unzip -q /workspace/pmsat-inference-and-publication-artifacts.zip -d /workspace
python3 /workspace/pmsat-inference/parse_all_results_timeouts.py /workspace/pmsat-inference/benchmarkingset-rc2-results > /workspace/repro.txt 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# output a cleaned table (only the % t.o. line formatted as percentages for n=8..17)
awk 'BEGIN{FS=","; OFS=","} /% t.o./{for(i=3;i<=12;i++){val=$i*100; printf("%0.1f%s", val, (i<12?"," : "\n"))}}' /workspace/repro.txt > /workspace/repro_percentages.csv
paste -d"," <(echo "n,8,9,10,11,12,13,14,15,16,17") /workspace/repro_percentages.csv
 echo '</artisan_submit>'
