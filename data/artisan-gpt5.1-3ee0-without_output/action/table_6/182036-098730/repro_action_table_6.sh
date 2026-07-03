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
# Pull the pre-built Docker image containing the artifact environment
docker pull islemdockerdev/github-workflow-resource-study:v1.1

# Start a long-running container following the required pattern
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# Install the project as a Python package inside the container so notebook imports work
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && python -m pip install ."

# Run a focused Python script inside the container to recompute the k-sensitivity
# for Table 6 and emit the final Markdown table to stdout, which we capture as /workspace/repro.txt
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && python - << 'PY'
import numpy as np
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers
from optimization.optimization_heuristics import get_wasted_schedule_1

# Recreate the analysis context as in paper_analysis_RQ3.ipynb
data_set = RunsDataSet('.', 'all_')
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()
all_repos = data_set.get_all_repositories()

tiers = get_tiers(all_repos)
repos_list_1 = tiers['paid']

# Subset to paid-tier repositories as in the notebook cell 29
all_runs_sub = all_runs[all_runs.repo_id.isin(repos_list_1)]

# Emit the exact Markdown structure expected for Table 6
print('**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**')
print()
print('| k                     |    1 |    2 |    5 |   10 |   15 |   20 |')
print('| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |')

k_values = [1, 2, 5, 10, 15, 20]
row_vals = []
for k in k_values:
    # get_wasted_schedule_1 returns a fraction of VM time saved; convert to a negative percentage impact
    impact = round(get_wasted_schedule_1(all_runs_sub, all_jobs, k)[2] * -100, 1)
    row_vals.append(impact)

row_str = '| Impact on VM time (%) | ' + ' | '.join(f'{v:.1f}' for v in row_vals) + ' |'
print(row_str)
PY" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
