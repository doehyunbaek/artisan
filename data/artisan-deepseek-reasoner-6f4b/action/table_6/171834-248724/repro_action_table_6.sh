#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**

| k                     |    1 |    2 |    5 |   10 |   15 |   20 |
| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |
| Impact on VM time (%) | -?.? | -?.? | -?.? | -?.? | -?.? | -?.? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
# Load Docker image and run container
docker image load -i gh_resource_study_artifact_patched/github-workflow-resource-optimization/github_study_container_patched.tar
CONTAINER_ID=$(docker run -d --init --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity')
# Wait a moment for container to be ready
sleep 5
# Copy reproduction script to container
cat > /tmp/reproduce_table6.py <<'EOSCRIPT'
import time
import os
import sys
sys.path.append('/workdir/src')
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers
from optimization.optimization_heuristics import get_wasted_schedule_1
os.chdir('/workdir')
print("Loading dataset...")
start = time.time()
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir="./")
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()
repos_list_1, repos_list_2 = get_tiers(data_set)
end = time.time()
print(f"Dataset loaded in {round(end - start, 1)} seconds")
all_runs_sub = all_runs[all_runs.repo_id.isin(repos_list_1)]
results = {}
for k in [1, 2, 5, 10, 15, 20]:
    impact = get_wasted_schedule_1(all_runs_sub, all_jobs, k)[2] * 100
    results[k] = round(impact, 1)
    print(f"{k}: -{results[k]:.1f}%")
EOSCRIPT
docker cp /tmp/reproduce_table6.py $CONTAINER_ID:/workdir/reproduce_table6.py
# Run the reproduction script and capture output
docker exec $CONTAINER_ID python /workdir/reproduce_table6.py > /workspace/repro.txt 2>&1
# Extract the results from the output (last 6 lines)
tail -6 /workspace/repro.txt > /workspace/repro_results.txt
# Clean up the container
docker stop $CONTAINER_ID
docker rm $CONTAINER_ID
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro_results.txt
echo '</artisan_submit>'
