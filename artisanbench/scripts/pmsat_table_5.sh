#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o pmsat-inference-and-publication-artifacts.zip https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content
unzip pmsat-inference-and-publication-artifacts.zip -d pmsat-inference-and-publication-artifacts
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker rm -f pmsat_table5 || true
docker run -d --init --name pmsat_table5 -v "$(pwd)":/pmsat-inference --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity'
docker exec pmsat_table5 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14"
docker exec pmsat_table5 /bin/bash --noprofile --norc -c "source /opt/venv/bin/activate && pip install 'numpy<2' --force-reinstall"
docker exec pmsat_table5 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/2804424892661995c1e6a665fa35e490 > table5.csv"
cp /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference/table5.csv /workspace/table5.csv
cd /workspace
{
  cat <<'EOTABLE2'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
EOTABLE2
  awk -F',' 'NR>1{
    # Strip spaces
    for(i=1;i<=6;i++){ gsub(/ /,"",$i) }
    # Skip the n=12 row (not shown in the paper table)
    if($1==12) next
    mean=$4
    sub(/\.0$/,"",mean)
    printf("| %2d | %7s | %9s | %11s | %10s | %8s |\n",$1,$2,$3,mean,$5,$6)
  }' table5.csv
} > /workspace/repro.txt
docker rm -f pmsat_table5 || true
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
