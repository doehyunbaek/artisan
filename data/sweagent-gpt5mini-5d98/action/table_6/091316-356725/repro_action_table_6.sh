#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**

| k                     |    1 |    2 |    5 |   10 |   15 |   20 |
| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |
| Impact on VM time (%) | -3.8 | -3.4 | -2.8 | -2.3 | -1.9 | -1.6 |

EOTABLE

# Section 2: Artifact download
if [ ! -f /workspace/gh_resource_study_artifact_patched.zip ]; then
  curl -sL "https://zenodo.org/records/10529665/files/gh_resource_study_artifact_patched.zip?download=1" -o /workspace/gh_resource_study_artifact_patched.zip
fi

# Section 3: Reproduction commands
# Unpack if needed
if [ ! -d /workspace/github-workflow-resource-optimization ]; then
  unzip -q /workspace/gh_resource_study_artifact_patched.zip -d /workspace/
fi

# Compute Table 6 values using the project's Python modules
PYTHONPATH=/workspace/github-workflow-resource-optimization/src python3 - <<'PY' > /workspace/repro.txt
import os
os.chdir('/workspace/github-workflow-resource-optimization')
from runs_collector.dataset import RunsDataSet
from optimization.optimization_heuristics import get_wasted_schedule_1

# Load dataset from checkpoints (fast loader as provided by the authors)
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir='./')
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()
# restrict to paid-tier repos (as used in the notebook)
from runs_analysis.resource_usage import get_tiers
repos_list_1, repos_list_2 = get_tiers(data_set)
all_runs_sub = all_runs[all_runs.repo_id.isin(repos_list_1)]

ks = [1,2,5,10,15,20]
values = []
for k in ks:
    # get_wasted_schedule_1 returns tuple where index 2 is waste over total time
    res = get_wasted_schedule_1(all_runs_sub, all_jobs, k)
    val = round(res[2]*100, 1)
    # authors present impact as negative numbers in the table
    values.append(-val)

# format output as markdown table row
print('| k                     |', ' | '.join(f'{k:>4}' for k in ks), '|')
print('| --------------------- |' + ' ---: |'*len(ks))
print('| Impact on VM time (%) |', ' | '.join(f'{v:>4.1f}' for v in values), '|')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'

# Copy the submission script to model.patch as requested
cp /workspace/repro_action_table_6.sh /root/model.patch || true
