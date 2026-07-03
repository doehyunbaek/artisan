#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**

| k                     |    1 |    2 |    5 |   10 |   15 |   20 |
| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |
| Impact on VM time (%) | -3.8 | -3.4 | -2.8 | -2.3 | -1.9 | -1.6 |

EOTABLE

# Section 2: Artifact download
cd /workspace
curl -L "https://zenodo.org/records/10529665/files/gh_resource_study_artifact_patched.zip" -o gh_resource_study_artifact_patched.zip
unzip -q gh_resource_study_artifact_patched.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# 3.1 Pull the Docker image from DockerHub
docker pull islemdockerdev/github-workflow-resource-study:v1.1

# 3.2 Start a long-running container using the recommended pattern
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# 3.3 Install the artifact package inside the container so notebook modules import correctly
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && pip install -e ."

# 3.4 Run the RQ3 k-sensitivity logic inside the container and capture raw output
docker exec github-study /bin/bash --noprofile --norc -c '
cd /workdir
python - << "PY"
import time, os, warnings
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers
from optimization.optimization_heuristics import get_wasted_schedule_1

warnings.filterwarnings("ignore")
os.chdir("/workdir")
print("Loading dataset from checkpoints")
start = time.time()
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir="./")
print("Time taken to load dataset:", round(time.time() - start, 1), "seconds")
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()
repos_list_1, repos_list_2 = get_tiers(data_set)
all_runs_sub = all_runs[all_runs.repo_id.isin(repos_list_1)]
print("{:<10} {:<25}".format("k", "Impact on VM time %"))
for k in [1, 2, 5, 10, 15, 20]:
    impact = get_wasted_schedule_1(all_runs_sub, all_jobs, k)[2] * 100
    print("{:<10} {:<25.1f}".format(k, impact))
PY
' > /workspace/k_sensitivity_raw.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'

# 4.1 Parse raw k-sensitivity output and build the Markdown table as /workspace/repro.txt
{
  echo '**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**'
  echo
  echo '| k                     |    1 |    2 |    5 |   10 |   15 |   20 |'
  echo '| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |'
  vals=$(awk '
    found && $1 ~ /^[0-9]+$/ {print $2}
    $1=="k" {found=1}
  ' /workspace/k_sensitivity_raw.txt | head -n 6 | paste -sd" " -)
  set -- $vals
  printf '| Impact on VM time (%%) | -%s | -%s | -%s | -%s | -%s | -%s |\n' "$1" "$2" "$3" "$4" "$5" "$6"
} > /workspace/repro.txt

# 4.2 Output the reproduced table
cat /workspace/repro.txt

echo '</artisan_submit>'
