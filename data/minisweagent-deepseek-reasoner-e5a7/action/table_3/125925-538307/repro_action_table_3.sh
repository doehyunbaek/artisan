#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Termination status: comparison between free tier and paid tier.**

| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |
| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |
| Success         |                     78.7 |                     88.9 |                        66.4 |                        81.1 |
| Failure         |                     17.4 |                     10.0 |                        30.9 |                        18.0 |
| Skipped         |                      2.2 |                      0.6 |                         0.0 |                         0.0 |
| Canceled        |                      1.5 |                      0.3 |                         2.7 |                         0.8 |
| Startup failure |                      0.1 |                      0.1 |                         0.0 |                         0.0 |
| Action required |                    < 0.1 |                      0.1 |                         0.0 |                         0.0 |
| Stale           |                    < 0.1 |                      0.0 |                         0.0 |                         0.0 |

EOTABLE
# Section 2: Artifact download
# Download the artifact from Zenodo
curl -L -o artifact.zip "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content"
# Extract the artifact
unzip -q artifact.zip -d artifact
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull the Docker image
docker pull islemdockerdev/github-workflow-resource-study:v1.1
# Run the container in detached mode
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
# Wait for container to be ready
sleep 10
# Install the package in the container
docker exec github-study bash -c "cd /workdir && pip install -e ."
# Run the analysis to generate Table 3
docker exec github-study python3 -c "
import time
import sys
sys.path.insert(0, '/workdir')
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers
workdir = '/workdir/'
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=workdir)
repos_list_1, repos_list_2 = get_tiers(data_set)
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()
all_runs_1 = all_runs[all_runs.repo_id.isin(repos_list_1)]
all_jobs_1 = all_jobs[(all_jobs.run_id.isin(all_runs_1.id)) & (all_jobs.id!=3253494537)]
all_runs_2 = all_runs[all_runs.repo_id.isin(repos_list_2)]
all_jobs_2 = all_jobs[(all_jobs.run_id.isin(all_runs_2.id)) & (all_jobs.id!=3253494537)]
conclusion_1 = all_runs_1.groupby('conclusion').agg({'id': 'count'}).reset_index()
conclusion_2 = all_runs_2.groupby('conclusion').agg({'id': 'count'}).reset_index()
conclusion_1['prop'] = conclusion_1['id'] * 100 / conclusion_1['id'].sum()
conclusion_2['prop'] = conclusion_2['id'] * 100 / conclusion_2['id'].sum()
runs_with_time_1 = all_runs_1.merge(all_jobs_1[['run_id', 'up_time']], left_on='id', right_on='run_id')
runs_with_time_2 = all_runs_2.merge(all_jobs_2[['run_id', 'up_time']], left_on='id', right_on='run_id')
time_per_conclusion_1 = runs_with_time_1.groupby('conclusion').agg({'up_time': 'sum'}).reset_index()
time_per_conclusion_1['prop'] = time_per_conclusion_1['up_time'] * 100 / time_per_conclusion_1.up_time.sum()
time_per_conclusion_2 = runs_with_time_2.groupby('conclusion').agg({'up_time': 'sum'}).reset_index()
time_per_conclusion_2['prop'] = time_per_conclusion_2['up_time'] * 100 / time_per_conclusion_2.up_time.sum()
print('{:<30} {:<24} {:<20}'.format('', 'Runs proportion %', 'VM time proportion %'))
print(' ' * 30 + '-' * 50)
print('{:<30} {:<12} {:<12} {:<12} {:<12}'.format('Conclusion', 'Paid', 'Free', 'Paid', 'Free'))
print('-' * 80)
for c in ['success', 'failure', 'skipped', 'cancelled', 'startup_failure', 'action_required', 'stale']:
    try:
        val1 = round(conclusion_1[conclusion_1.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        val1 = 0.0
    try:
        val2 = round(conclusion_2[conclusion_2.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        val2 = 0.0
    try:
        val3 = round(time_per_conclusion_1[time_per_conclusion_1.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        val3 = 0.0
    try:
        val4 = round(time_per_conclusion_2[time_per_conclusion_2.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        val4 = 0.0
    print('{:<30} {:<12} {:<12} {:<12} {:<12}'.format(c, val1, val2, val3, val4))
" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
