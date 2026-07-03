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
cd /workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization
PYTHONPATH=src uvx --from pandas python - <<'PY' > /workspace/repro.txt
import pandas as pd
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers

# Load checkpointed dataset (all_*.csv in current directory)
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=".")

# Derive paid (repos_list_1) and free (repos_list_2) tiers
repos_list_1, repos_list_2 = get_tiers(data_set)

all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()

# Filter runs and jobs by tier, mirroring notebook logic (cell 26)
all_runs_1 = all_runs[all_runs["repo_id"].isin(repos_list_1)]
all_runs_2 = all_runs[all_runs["repo_id"].isin(repos_list_2)]

all_jobs_1 = all_jobs[(all_jobs["run_id"].isin(all_runs_1["id"])) & (all_jobs["id"] != 3253494537)]
all_jobs_2 = all_jobs[(all_jobs["run_id"].isin(all_runs_2["id"])) & (all_jobs["id"] != 3253494537)]

# Runs proportion per conclusion
conclusion_1 = all_runs_1.groupby("conclusion", as_index=False).agg(id=("id", "count"))
conclusion_2 = all_runs_2.groupby("conclusion", as_index=False).agg(id=("id", "count"))
conclusion_1["prop"] = conclusion_1["id"] * 100.0 / conclusion_1["id"].sum()
conclusion_2["prop"] = conclusion_2["id"] * 100.0 / conclusion_2["id"].sum()

# VM time proportion per conclusion
runs_with_time_1 = all_runs_1.merge(all_jobs_1[["run_id", "up_time"]], left_on="id", right_on="run_id")
runs_with_time_2 = all_runs_2.merge(all_jobs_2[["run_id", "up_time"]], left_on="id", right_on="run_id")

time_per_conclusion_1 = runs_with_time_1.groupby("conclusion", as_index=False).agg(up_time=("up_time", "sum"))
time_per_conclusion_2 = runs_with_time_2.groupby("conclusion", as_index=False).agg(up_time=("up_time", "sum"))
time_per_conclusion_1["prop"] = time_per_conclusion_1["up_time"] * 100.0 / time_per_conclusion_1["up_time"].sum()
time_per_conclusion_2["prop"] = time_per_conclusion_2["up_time"] * 100.0 / time_per_conclusion_2["up_time"].sum()

def get_prop(df, concl):
    s = df.loc[df["conclusion"] == concl, "prop"]
    if s.empty:
        return 0.0
    return round(float(s.iloc[0]), 1)

# Map human-readable status labels (first column) to underlying conclusion codes
rows = [
    ("Success",         "success"),
    ("Failure",         "failure"),
    ("Skipped",         "skipped"),
    ("Canceled",        "cancelled"),        # note: conclusion value is 'cancelled'
    ("Startup failure", "startup_failure"),
    ("Action required", "action_required"),
    ("Stale",           "stale"),
]

# Emit Markdown table matching the expected structure, with computed percentages
print("**Table 3: Termination status: comparison between free tier and paid tier.**")
print()
print("| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |")
print("| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |")

for label, code in rows:
    rp_paid  = get_prop(conclusion_1, code)
    rp_free  = get_prop(conclusion_2, code)
    vt_paid  = get_prop(time_per_conclusion_1, code)
    vt_free  = get_prop(time_per_conclusion_2, code)
    print(f"| {label:<14} | {rp_paid:>23.1f} | {rp_free:>23.1f} | {vt_paid:>25.1f} | {vt_free:>25.1f} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
