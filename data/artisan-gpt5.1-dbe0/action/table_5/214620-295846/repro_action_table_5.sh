#!/usr/bin/bash
# Section 1: Expected table (keep the obfuscated template)
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=?) | ?.?% (<?.?%) of all runs<br>??.?% (?.?%) of scheduled runs |  ?.?% (<?.?%) of all runs time<br>??.?% (?.?%) of scheduled runs time |                         -???.?? (-?.??) |
| Deactivate scheduled workflows during repository inactivity       |  ?.?% (?.?%) of all runs<br>??.?% (?.?%) of scheduled runs | <?.?% (<?.?%) of all runs time<br>?.?% (?.?%) of scheduled runs time |                          -??.?? (-?.??) |
| Run previously failed jobs first                                  |     ?.?% (?.?%) of all runs<br>??.?% (?.?%) of failed runs |    ?.?% (<?.?%) of all runs time<br>??.?% (??.?%) of failed runs time |                          -??.?? (-?.??) |
| Project-specific timeouts                                         |                                   ?.?% (<?.?%) of all runs |                                          ?.?% (?.?%) of all runs time |                        -???.?? (-??.??) |

* measurement for paid tier (measurement for free tier)
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665

# Section 3: Reproduction commands – recompute Table 5 from artifact data
cd /workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization

# Install dependencies and the package from the artifact
pip install -r requirements.txt >/dev/null 2>&1
pip install . >/dev/null 2>&1

# Run RQ3-style analysis and format the table
python3 - <<'PY' > /workspace/repro.txt
import os
import json
import numpy as np

from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers, calculate_costs
from optimization.optimization_heuristics import (
    compute_wasted_schedule1,
    compute_wasted_schedule2,
    failed_jobs_prioritization,
    timeout_value_optimization,
)

os.chdir("/workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization")

# Load dataset from checkpoints (as in paper_analysis_RQ3.ipynb)
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir="./")

all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()

jobs_runs_time = all_jobs.groupby("run_id").agg({"up_time": "sum", "start_ts": "min"}).reset_index()
runs_with_time = all_runs.merge(jobs_runs_time, left_on="id", right_on="run_id")

repos_list_1, repos_list_2 = get_tiers(data_set)
optimizations = {}

# 1) Deactivate scheduled workflows after k consecutive failures (k=3)
wasted_schedule_paid = compute_wasted_schedule1(all_runs, all_jobs, repos_list_1)
wasted_schedule_free = compute_wasted_schedule1(all_runs, all_jobs, repos_list_2)

optimizations["wasted_schedule"] = {
    "paid": {
        "all_runs": wasted_schedule_paid[0] * 100,
        "subset_runs": wasted_schedule_paid[1] * 100,
        "saved_time_all": wasted_schedule_paid[2] * 100,
        "saved_subset": wasted_schedule_paid[3] * 100,
        "saved_cost": wasted_schedule_paid[4],
    },
    "free": {
        # note: for free, all_runs is left in percent units as in the notebook
        "all_runs": wasted_schedule_free[0],
        "subset_runs": wasted_schedule_free[1] * 100,
        "saved_time_all": wasted_schedule_free[2] * 100,
        "saved_subset": wasted_schedule_free[3] * 100,
        "saved_cost": wasted_schedule_free[4],
    },
}

# 2) Deactivate scheduled workflows during repository inactivity
all_repos = data_set.get_all_repositories()

commits_dict = {}
with open("commits_messages_by_repo.json") as cmr:
    collected_messages = json.load(cmr)
for cm in collected_messages:
    if cm:
        repo_name = cm[0][0]
        commits_dict.setdefault(repo_name, []).extend([x[1] for x in cm])

commits_dict_2 = {}
with open("scraped_commits_messages_part2.json") as cmr:
    collected_messages = json.load(cmr)
for cm in collected_messages:
    repo_name = cm[0]
    commits_dict_2.setdefault(repo_name, []).append(cm[1])

commits_dict_3 = {}
with open("collected_commits_messages_part3.json") as cmm:
    collected_messages = json.load(cmm)
for cm in collected_messages:
    repo_name = cm[0]
    commits_dict_3.setdefault(repo_name, []).append(cm[1])

commits_dict_3.update(commits_dict_2)
commits_dict_3.update(commits_dict)

all_runs_sub_1, total_waste_time, total_over_schedule, total_over_total, wasted_fails, saved_cost = compute_wasted_schedule2(
    all_runs, all_jobs, all_repos, commits_dict_3, repos_list_1
)
all_runs_sub_2, total_waste_time2, total_over_schedule2, total_over_total2, wasted_fails2, saved_cost2 = compute_wasted_schedule2(
    all_runs, all_jobs, all_repos, commits_dict_3, repos_list_2
)

optimizations["wasted_schedule_2"] = {
    "paid": {
        "all_runs": len(wasted_fails) / all_runs_sub_1.shape[0] * 100,
        "subset_runs": len(wasted_fails) / all_runs_sub_1[all_runs_sub_1.event == "schedule"].shape[0] * 100,
        "saved_time_all": total_over_total,
        "saved_subset": total_over_schedule,
        "saved_cost": saved_cost,
    },
    "free": {
        "all_runs": len(wasted_fails2) / all_runs_sub_2.shape[0] * 100,
        "subset_runs": len(wasted_fails2) / all_runs_sub_2[all_runs_sub_2.event == "schedule"].shape[0] * 100,
        "saved_time_all": total_over_total2,
        "saved_subset": total_over_schedule2,
        "saved_cost": saved_cost2,
    },
}

# 3) Run previously failed jobs first
time_overall, time_over_impacted, impacted_runs, inlined_ids = failed_jobs_prioritization(data_set, repos_list_1)
impact_over_subset = (
    all_runs[all_runs.id.isin(all_jobs[all_jobs.id.isin(inlined_ids)].run_id.to_list())].id.unique().shape[0]
    / all_runs_sub_1[all_runs_sub_1.conclusion == "failure"].shape[0] * 100
    + len(inlined_ids) / all_runs_sub_1[all_runs_sub_1.conclusion == "failure"].shape[0] * 100
)

sub_runs = all_runs[all_runs.id.isin(all_jobs[all_jobs.id.isin(inlined_ids)].run_id.to_list())]
min_max_start_ts = sub_runs.groupby("repo_id").start_ts.agg(["min", "max"]).reset_index()
total_start_ts = 0
for _, row in min_max_start_ts.iterrows():
    total_start_ts += row["max"] - row["min"]
years = total_start_ts / (12 * 30 * 24 * 3600)
delta_cost = calculate_costs(all_jobs[all_jobs.id.isin(inlined_ids)].up_time.sum() / 60 / years)

time_overall2, time_over_impacted2, impacted_runs2, inlined_ids2 = failed_jobs_prioritization(data_set, repos_list_2)
impact_over_subset2 = (
    all_runs[all_runs.id.isin(all_jobs[all_jobs.id.isin(inlined_ids2)].run_id.to_list())].id.unique().shape[0]
    / all_runs_sub_2[all_runs_sub_2.conclusion == "failure"].shape[0] * 100
)

sub_runs2 = all_runs[all_runs.id.isin(all_jobs[all_jobs.id.isin(inlined_ids2)].run_id.to_list())]
min_max_start_ts2 = sub_runs2.groupby("repo_id").start_ts.agg(["min", "max"]).reset_index()
total_start_ts2 = 0
for _, row in min_max_start_ts2.iterrows():
    total_start_ts2 += row["max"] - row["min"]
years2 = total_start_ts2 / (12 * 30 * 24 * 3600)
delta_cost2 = calculate_costs(all_jobs[all_jobs.id.isin(inlined_ids2)].up_time.sum() / 60 / years2)

optimizations["failed_jobs"] = {
    "paid": {
        "all_runs": impacted_runs,
        "subset_runs": impact_over_subset,
        "saved_time_all": time_overall * 100,
        "saved_subset": time_over_impacted * 100,
        "saved_cost": delta_cost,
    },
    "free": {
        "all_runs": impacted_runs2,
        "subset_runs": impact_over_subset2,
        "saved_time_all": time_overall2 * 100,
        "saved_subset": time_over_impacted2 * 100,
        "saved_cost": delta_cost2,
    },
}

# 4) Project-specific timeouts
sub_repos_list = repos_list_1
saved_time, impacted_runs = timeout_value_optimization(data_set, sub_repos_list)
all_runs_local = data_set.get_all_runs()
impacted_runs1 = len(impacted_runs) / all_runs_local[all_runs_local.repo_id.isin(sub_repos_list)].shape[0] * 100
saved_time1 = (
    sum([s for s in saved_time if not np.isnan(s)])
    / all_jobs[all_jobs.run_id.isin(all_runs_local[all_runs_local.repo_id.isin(sub_repos_list)].id.to_list())].up_time.sum()
    * 100
)

sub_runs = all_runs_local[all_runs_local.id.isin(impacted_runs)]
min_max_start_ts = sub_runs.groupby("repo_id").start_ts.agg(["min", "max"]).reset_index()
total_start_ts = 0
for _, row in min_max_start_ts.iterrows():
    total_start_ts += row["max"] - row["min"]
years = total_start_ts / (12 * 30 * 24 * 3600)
saved_cost1 = calculate_costs(sum([s for s in saved_time if not np.isnan(s)]) / 60 / years)

sub_repos_list = repos_list_2
saved_time, impacted_runs = timeout_value_optimization(data_set, sub_repos_list)
all_runs_local = data_set.get_all_runs()
impacted_runs2 = len(impacted_runs) / all_runs_local[all_runs_local.repo_id.isin(sub_repos_list)].shape[0] * 100
saved_time2 = (
    sum([s for s in saved_time if not np.isnan(s)])
    / all_jobs[all_jobs.run_id.isin(all_runs_local[all_runs_local.repo_id.isin(sub_repos_list)].id.to_list())].up_time.sum()
    * 100
)

sub_runs = all_runs_local[all_runs_local.id.isin(impacted_runs)]
min_max_start_ts = sub_runs.groupby("repo_id").start_ts.agg(["min", "max"]).reset_index()
total_start_ts = 0
for _, row in min_max_start_ts.iterrows():
    total_start_ts += row["max"] - row["min"]
years = total_start_ts / (12 * 30 * 24 * 3600)
saved_cost2 = calculate_costs(sum([s for s in saved_time if not np.isnan(s)]) / 60 / years)

optimizations["vm_timeout"] = {
    "paid": {
        "all_runs": impacted_runs1,
        "saved_time_all": saved_time1,
        "saved_cost": saved_cost1,
    },
    "free": {
        "all_runs": impacted_runs2,
        "saved_time_all": saved_time2,
        "saved_cost": saved_cost2,
    },
}

# Formatting helpers
def fmt_all_runs(v: float) -> str:
    v = float(v)
    if 0 < abs(v) < 0.1:
        return "<0.1%"
    return f"{round(v, 1):.1f}%"

def fmt_time_all(v: float) -> str:
    v = float(v)
    if 0 < abs(v) < 0.1:
        return "<0.1%"
    return f"{round(v, 1):.1f}%"

def fmt_subset(v: float) -> str:
    v = float(v)
    return f"{round(v, 1):.1f}%"

def fmt_cost(v: float) -> str:
    return f"{float(v):.2f}"

ws = optimizations["wasted_schedule"]
ws2 = optimizations["wasted_schedule_2"]
fj = optimizations["failed_jobs"]
to_ = optimizations["vm_timeout"]

print("**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**\n")
print("| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |")
print("| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |")

# Row 1: Deactivate after k failures
imp_runs_ws = (
    f"{fmt_all_runs(ws['paid']['all_runs'])} ({fmt_all_runs(ws['free']['all_runs'])}) of all runs<br>"
    f"{fmt_subset(ws['paid']['subset_runs'])} ({fmt_subset(ws['free']['subset_runs'])}) of scheduled runs"
)
time_ws = (
    f"{fmt_time_all(ws['paid']['saved_time_all'])} ({fmt_time_all(ws['free']['saved_time_all'])}) of all runs time<br>"
    f"{fmt_subset(ws['paid']['saved_subset'])} ({fmt_subset(ws['free']['saved_subset'])}) of scheduled runs time"
)
cost_ws = f"-{fmt_cost(ws['paid']['saved_cost'])} (-{fmt_cost(ws['free']['saved_cost'])})"
print(f"| Deactivate scheduled workflows after k consecutive failures (k=3) | {imp_runs_ws} | {time_ws} | {cost_ws} |")

# Row 2: Deactivate during inactivity
imp_runs_ws2 = (
    f"{fmt_all_runs(ws2['paid']['all_runs'])} ({fmt_all_runs(ws2['free']['all_runs'])}) of all runs<br>"
    f"{fmt_subset(ws2['paid']['subset_runs'])} ({fmt_subset(ws2['free']['subset_runs'])}) of scheduled runs"
)
time_ws2 = (
    f"{fmt_time_all(ws2['paid']['saved_time_all'])} ({fmt_time_all(ws2['free']['saved_time_all'])}) of all runs time<br>"
    f"{fmt_subset(ws2['paid']['saved_subset'])} ({fmt_subset(ws2['free']['saved_subset'])}) of scheduled runs time"
)
cost_ws2 = f"-{fmt_cost(ws2['paid']['saved_cost'])} (-{fmt_cost(ws2['free']['saved_cost'])})"
print(f"| Deactivate scheduled workflows during repository inactivity       | {imp_runs_ws2} | {time_ws2} | {cost_ws2} |")

# Row 3: Run previously failed jobs first
imp_runs_fj = (
    f"{fmt_all_runs(fj['paid']['all_runs'])} ({fmt_all_runs(fj['free']['all_runs'])}) of all runs<br>"
    f"{fmt_subset(fj['paid']['subset_runs'])} ({fmt_subset(fj['free']['subset_runs'])}) of failed runs"
)
time_fj = (
    f"{fmt_time_all(fj['paid']['saved_time_all'] / 100.0)} ({fmt_time_all(fj['free']['saved_time_all'] / 100.0)}) of all runs time<br>"
    f"{fmt_subset(fj['paid']['saved_subset'] / 100.0)} ({fmt_subset(fj['free']['saved_subset'] / 100.0)}) of failed runs time"
)
cost_fj = f"-{fmt_cost(fj['paid']['saved_cost'])} (-{fmt_cost(fj['free']['saved_cost'])})"
print(f"| Run previously failed jobs first                                  | {imp_runs_fj} | {time_fj} | {cost_fj} |")

# Row 4: Project-specific timeouts
imp_runs_to = (
    f"{fmt_all_runs(to_['paid']['all_runs'])} ({fmt_all_runs(to_['free']['all_runs'])}) of all runs"
)
time_to = (
    f"{fmt_time_all(to_['paid']['saved_time_all'])} ({fmt_time_all(to_['free']['saved_time_all'])}) of all runs time"
)
cost_to = f"-{fmt_cost(to_['paid']['saved_cost'])} (-{fmt_cost(to_['free']['saved_cost'])})"
print(f"| Project-specific timeouts                                         | {imp_runs_to} | {time_to} | {cost_to} |")

print("\n* measurement for paid tier (measurement for free tier)")
PY

# Section 4: Formatting and submission block
cd /workspace
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
