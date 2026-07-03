#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           ? |         ?? |                ?.?? |                 ?? |               ?? |
|   4 |           ? |          ? |                ?.?? |                  ? |               ?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build
docker rm -f pmsat_table2 || true
docker run -d --init --entrypoint bash -v "$PWD":/pmsat-inference --name pmsat_table2 pmsat-inference-pmsat -c 'sleep infinity'
docker exec pmsat_table2 /bin/bash --noprofile --norc -c "/opt/venv/bin/pip install 'numpy<2'"
docker exec pmsat_table2 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7"
docker exec pmsat_table2 /bin/bash --noprofile --norc -c "cd /pmsat-inference && python parse_single_run_results.py TRACE-results/92e710ef352c4739cd7569794272588a > table2.csv"
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference
{
cat <<'EOT'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\delta_g) fr. | Max (\delta_g) fr. | Min (\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
EOT
awk -F, 'NR==2 || NR==3{
  for(i=1;i<=6;i++){gsub(/^ *| *$/,"",$i)}
  printf "| %3s | %11s | %9s | %18s | %17s | %15s |\n",$1,$2,$3,$4,$5,$6
}' table2.csv
} > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
