#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summary of resource usage by triggering event.**

| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Pull Request |             50.7 |             35.5 |          38.6 |          25.3 |                 31.1 (20.1) |                   3.6 (3.6) |                      0.36 |                      0.04 |
| Push         |             30.9 |             47.8 |          26.4 |          28.6 |                 28.4 (19.5) |                   4.3 (4.2) |                      0.33 |                      0.05 |
| Schedule     |             15.5 |             14.5 |          26.2 |          40.3 |                  13.8 (1.3) |                   0.9 (0.2) |                      0.17 |                      0.01 |
| PR target    |              1.2 |              0.6 |           4.2 |           1.4 |                  8.5 (11.9) |                   1.2 (1.3) |                      0.08 |                      0.01 |
| Dispatch     |              0.7 |              0.5 |           0.2 |           0.3 |                 71.9 (24.9) |                   5.1 (4.4) |                      0.87 |                      0.06 |
| Workflow run |              0.7 |              0.0 |           0.7 |           0.4 |                 23.2 (13.0) |                   0.1 (0.1) |                      0.19 |                     <0.01 |
| Release      |              0.2 |              0.5 |           0.1 |           0.3 |                 40.0 (15.0) |                   4.2 (5.9) |                      0.32 |                      0.03 |
| Others       |              0.1 |              0.6 |           3.6 |           3.4 |                   4.5 (1.4) |                   0.7 (0.6) |                      0.05 |                      0.01 |

* mean (inter-quartile range)

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -s https://zenodo.org/api/records/10529665 | python3 -c "
import json, sys
data = json.load(sys.stdin)
for file in data['files']:
    if file['key'].endswith('.zip'):
        print(file['links']['self'])
        break
" | while read url; do curl -L -o artifact.zip "$url"; done
unzip -q artifact.zip
# Section 3: Reproduction commands
cd /workspace/github-workflow-resource-optimization
docker image load -i github_study_container_patched.tar
container_id=$(docker run -d --init --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity')
sleep 5  # Wait for container to start
docker exec $container_id /bin/bash -c "cd /workdir && . .venv2/bin/activate && python -m jupyter nbconvert --execute --to notebook --inplace paper_analysis_RQ1.ipynb" > /workspace/nbconvert.log 2>&1
# Extract the table from the notebook and save to repro.txt
docker exec $container_id python3 -c "
import json
with open('/workdir/paper_analysis_RQ1.ipynb', 'r') as f:
    nb = json.load(f)
for cell in nb['cells']:
    if 'outputs' in cell and cell['outputs']:
        for output in cell['outputs']:
            if output.get('name') == 'stdout' and 'text' in output:
                for line in output['text']:
                    if 'Event' in line or 'pull_request' in line or 'push' in line or 'schedule' in line or 'pull_request_target' in line or 'workflow_dispatch' in line or 'workflow_run' in line or 'release' in line or 'Others' in line:
                        print(line.rstrip())
" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
