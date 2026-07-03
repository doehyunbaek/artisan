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
CID=$(docker run -d --init --entrypoint bash -v "$PWD":/pmsat-inference pmsat-inference-pmsat -c 'sleep infinity')
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_all_results_timeouts.py benchmarkingset-rc2-results > table3.csv"
# Build markdown reproduction table
cat > /workspace/repro.txt <<'EOT'
**Table 3: Percentage of the 400 experiments per number of states that ran into the one hour timeout.**

| n         |   8 |   9 |  10 |  11 |  12 |  13 |   14 |   15 | 16 | 17 |
| --------- | --: | --: | --: | --: | --: | --: | ---: | ---: | -: | -: |
EOT
awk -F',' '
NR==1 {
  for (i=2;i<=NF;i++) {
    gsub(/[ \t]/,"",$i);
    header[i]=$i;
  }
}
NR==3 {
  for (i=2;i<=NF;i++) {
    gsub(/[ \t]/,"",$i);
    val[i]=$i;
  }
}
END {
  for (i=2;i<=NF;i++) {
    n=header[i];
    pct[n]=val[i]*100;
  }
  printf "| timeout %% |";
  for (n=8;n<=17;n++) {
    printf " %.1f |", pct[n];
  }
  printf "\n";
}
' table3.csv >> /workspace/repro.txt
docker rm -f "$CID" >/dev/null 2>&1 || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
