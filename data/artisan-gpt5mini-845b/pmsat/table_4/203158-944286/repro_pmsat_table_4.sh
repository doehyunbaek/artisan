#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  7 |       ? |         ?? |            ? |           ? |         ? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10423670
# Section 3: Reproduction commands (populate from reviewed steps)
cd pmsat-inference-and-publication-artifacts/pmsat-inference || exit 1
docker-compose build
docker-compose run -d pmsat /bin/bash -c 'sleep infinity'
# find the running container for the mounted service
CID=$(docker ps -q --filter "name=pmsat-inference-pmsat-run")
# run the mining step (will create TRACE-results)
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/python3.10 run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13"
# ensure matplotlib/numpy compatibility and parse results -> capture to /workspace/repro.txt
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /pmsat-inference && /opt/venv/bin/pip install --upgrade 'numpy<2' && MPLBACKEND=Agg /opt/venv/bin/python3.10 parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409" > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
