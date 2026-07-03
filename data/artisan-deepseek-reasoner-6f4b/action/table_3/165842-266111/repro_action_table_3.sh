#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Termination status: comparison between free tier and paid tier.**

| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |
| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |
| Success         |                     ??.? |                     ??.? |                        ??.? |                        ??.? |
| Failure         |                     ??.? |                     ??.? |                        ??.? |                        ??.? |
| Skipped         |                      ?.? |                      ?.? |                         ?.? |                         ?.? |
| Canceled        |                      ?.? |                      ?.? |                         ?.? |                         ?.? |
| Startup failure |                      ?.? |                      ?.? |                         ?.? |                         ?.? |
| Action required |                    < ?.? |                      ?.? |                         ?.? |                         ?.? |
| Stale           |                    < ?.? |                      ?.? |                         ?.? |                         ?.? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
cd gh_resource_study_artifact_patched/github-workflow-resource-optimization
docker load -i github_study_container_patched.tar
docker run -d --init --name github-study -v $(pwd):/workdir islemdockerdev/github-workflow-resource-study:v1.1 sleep infinity
docker exec github-study /bin/bash -c "cd /workdir && pip install -e ."
docker exec github-study /bin/bash -c "cd /workdir && python -c '
import time
import pandas as pd
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers

print(\"Loading dataset...\")
start = time.time()
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=\"./\")
end = time.time()
print(f\"Time taken to load the dataset: {round(end - start, 0)} seconds\")

print(\"Computing paid and free repository tiers...\")
repos_list_1, repos_list_2 = get_tiers(data_set)
print(f\"Paid repos count: {len(repos_list_1)}\")
print(f\"Free repos count: {len(repos_list_2)}\")

all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()

all_runs_1 = all_runs[all_runs.repo_id.isin(repos_list_1)]
all_jobs_1 = all_jobs[(all_jobs.run_id.isin(all_runs_1.id)) & (all_jobs.id!=3253494537)]

all_runs_2 = all_runs[all_runs.repo_id.isin(repos_list_2)]
all_jobs_2 = all_jobs[(all_jobs.run_id.isin(all_runs_2.id)) & (all_jobs.id!=3253494537)]

conclusion_1 = all_runs_1.groupby(\"conclusion\").agg({\"id\": \"count\"}).reset_index()
conclusion_2 = all_runs_2.groupby(\"conclusion\").agg({\"id\": \"count\"}).reset_index()
conclusion_1[\"prop\"] = conclusion_1[\"id\"] * 100/conclusion_1[\"id\"].sum()
conclusion_2[\"prop\"] = conclusion_2[\"id\"] * 100/conclusion_2[\"id\"].sum()

runs_with_time_1 = all_runs_1.merge(all_jobs_1[[\"run_id\", \"up_time\"]], left_on=\"id\", right_on=\"run_id\")
runs_with_time_2 = all_runs_2.merge(all_jobs_2[[\"run_id\", \"up_time\"]], left_on=\"id\", right_on=\"run_id\")

time_per_conclusion_1 = runs_with_time_1.groupby(\"conclusion\").agg({\"up_time\": \"sum\"}).reset_index()
time_per_conclusion_1[\"prop\"] = time_per_conclusion_1[\"up_time\"]*100/time_per_conclusion_1.up_time.sum()

time_per_conclusion_2 = runs_with_time_2.groupby(\"conclusion\").agg({\"up_time\": \"sum\"}).reset_index()
time_per_conclusion_2[\"prop\"] = time_per_conclusion_2[\"up_time\"]*100/time_per_conclusion_2.up_time.sum()

# Output table
print(\"\n\" + \" \"*30 + \"Table 3: Termination status: comparison between free tier and paid tier.\")
print(\"{:<30} {:<24} {:<20}\".format(\"\", \"Runs proportion %\", \"VM time proportion %\"))
print(\" \"*30 + \"-\"*50)
print(\"{:<30} {:<12} {:<12} {:<12} {:<12}\".format(\"Status\", \"Paid\", \"Free\", \"Paid\", \"Free\"))
print(\"-\"*80)
for c in [\"success\", \"failure\", \"skipped\", \"cancelled\", \"startup_failure\", \"action_required\", \"stale\"]:
    try:
        c1_val = round(conclusion_1[conclusion_1.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        c1_val = 0.0
    try:
        c2_val = round(conclusion_2[conclusion_2.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        c2_val = 0.0
    try:
        t1_val = round(time_per_conclusion_1[time_per_conclusion_1.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        t1_val = 0.0
    try:
        t2_val = round(time_per_conclusion_2[time_per_conclusion_2.conclusion==c].prop.to_list()[0], 1)
    except IndexError:
        t2_val = 0.0
    print(\"{:<30} {:<12} {:<12} {:<12} {:<12}\".format(c, c1_val, c2_val, t1_val, t2_val))
'" > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
