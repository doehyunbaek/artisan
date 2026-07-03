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
docker-compose run pmsat python parse_all_results_timeouts.py benchmarkingset-rc2-results > table3.csv
{
  echo "**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**"
  echo
  echo "| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |"
  echo "| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |"
  printf "| timeout %% |"
  awk -F',' 'NR==3 { for (i=8; i<=17; i++) { gsub(/^[ \t]+|[ \t]+$/,"",$i); val=$i*100; printf " %.1f |", val } } END { print "" }' table3.csv
} > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
