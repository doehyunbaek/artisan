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
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --entrypoint bash --name github-study islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
docker exec github-study /bin/bash --noprofile --norc -c "/workdir/.venv2/bin/python - << 'PY'
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers

workdir = \"/workdir/\"
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=workdir)

# Split repositories into paid and free tiers
repos_list_1, repos_list_2 = get_tiers(data_set)

# Load runs and jobs
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()

# Filter runs and jobs per tier (excluding the specific job ID as in the notebook)
all_runs_1 = all_runs[all_runs.repo_id.isin(repos_list_1)]
all_jobs_1 = all_jobs[(all_jobs.run_id.isin(all_runs_1.id)) & (all_jobs.id != 3253494537)]

all_runs_2 = all_runs[all_runs.repo_id.isin(repos_list_2)]
all_jobs_2 = all_jobs[(all_jobs.run_id.isin(all_runs_2.id)) & (all_jobs.id != 3253494537)]

# Proportion of runs per conclusion
conclusion_1 = all_runs_1.groupby(\"conclusion\").agg({\"id\": \"count\"}).reset_index()
conclusion_2 = all_runs_2.groupby(\"conclusion\").agg({\"id\": \"count\"}).reset_index()
conclusion_1[\"prop\"] = conclusion_1[\"id\"] * 100 / conclusion_1[\"id\"].sum()
conclusion_2[\"prop\"] = conclusion_2[\"id\"] * 100 / conclusion_2[\"id\"].sum()

# VM time proportions per conclusion
runs_with_time_1 = all_runs_1.merge(all_jobs_1[[\"run_id\", \"up_time\"]], left_on=\"id\", right_on=\"run_id\")
runs_with_time_2 = all_runs_2.merge(all_jobs_2[[\"run_id\", \"up_time\"]], left_on=\"id\", right_on=\"run_id\")

time_per_conclusion_1 = runs_with_time_1.groupby(\"conclusion\").agg({\"up_time\": \"sum\"}).reset_index()
time_per_conclusion_1[\"prop\"] = time_per_conclusion_1[\"up_time\"] * 100 / time_per_conclusion_1.up_time.sum()

time_per_conclusion_2 = runs_with_time_2.groupby(\"conclusion\").agg({\"up_time\": \"sum\"}).reset_index()
time_per_conclusion_2[\"prop\"] = time_per_conclusion_2[\"up_time\"] * 100 / time_per_conclusion_2.up_time.sum()

def get_prop(df, key):
    row = df[df.conclusion == key]
    if row.empty:
        return 0.0
    return round(float(row.prop.iloc[0]), 1)

statuses = [
    (\"Success\", \"success\"),
    (\"Failure\", \"failure\"),
    (\"Skipped\", \"skipped\"),
    (\"Canceled\", \"cancelled\"),  # GitHub uses \"cancelled\" internally
    (\"Startup failure\", \"startup_failure\"),
    (\"Action required\", \"action_required\"),
    (\"Stale\", \"stale\"),
]

print(\"**Table 3: Termination status: comparison between free tier and paid tier.**\\n\")
print(\"| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |\")
print(\"| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |\")

for label, key in statuses:
    rp1 = get_prop(conclusion_1, key)
    rp2 = get_prop(conclusion_2, key)
    tp1 = get_prop(time_per_conclusion_1, key)
    tp2 = get_prop(time_per_conclusion_2, key)
    print(f\"| {label:14} | {rp1:23.1f} | {rp2:23.1f} | {tp1:26.1f} | {tp2:26.1f} |\")
PY" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
