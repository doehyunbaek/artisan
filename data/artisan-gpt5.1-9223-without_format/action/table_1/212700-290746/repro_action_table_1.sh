#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summary of resource usage by triggering event.**

| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Pull Request |             ??.? |             ??.? |          ??.? |          ??.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Push         |             ??.? |             ??.? |          ??.? |          ??.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Schedule     |             ??.? |             ??.? |          ??.? |          ??.? |                  ??.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| PR target    |              ?.? |              ?.? |           ?.? |           ?.? |                  ?.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Dispatch     |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Workflow run |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                     <?.?? |
| Release      |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Others       |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |

* mean (inter-quartile range)

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization
python -m pip install --quiet pandas
python - << 'PY' > /workspace/repro.txt
import os
import pandas as pd
from src.runs_analysis import resource_usage as ru

class DataSet:
    def __init__(self, base: str):
        self.base = base
        self._runs = pd.read_csv(os.path.join(base, "all_runs.csv"))
        self._jobs = pd.read_csv(os.path.join(base, "all_jobs.csv"))
        self._steps = pd.read_csv(os.path.join(base, "all_steps.csv"))

    def get_all_runs(self):
        return self._runs

    def get_all_jobs(self):
        return self._jobs

    def get_all_steps(self):
        return self._steps


data_set = DataSet(".")

# Recreate the notebook computations for Table 1
repos_list_1, repos_list_2 = ru.get_tiers(data_set)
runs_prop_1 = ru.triggering_events_proportion(data_set, repos_list_1)
runs_prop_2 = ru.triggering_events_proportion(data_set, repos_list_2)
time_prop_1 = ru.triggering_events_time_proportion(data_set, repos_list_1)
time_prop_2 = ru.triggering_events_time_proportion(data_set, repos_list_2)
avg_time_1 = ru.get_avg_runtime_by_event(data_set, repos_list_1)
avg_time_2 = ru.get_avg_runtime_by_event(data_set, repos_list_2)

def calc_others():
    # Aggregate percentages for known events, then use get_avg_runtime_rest for "others"
    events = ["pull_request", "push", "schedule", "pull_request_target", "workflow_dispatch", "workflow_run", "release"]
    c1 = c2 = c3 = c4 = 0.0
    for event in events:
        c1 += round(time_prop_1.get(event, 0.0), 1)
        c2 += round(time_prop_2.get(event, 0.0), 1)
        c3 += round(runs_prop_1.get(event, 0.0), 1)
        c4 += round(runs_prop_2.get(event, 0.0), 1)

    # Match the notebook's event exclusion list (including its original spelling)
    rest_2 = ru.get_avg_runtime_rest(
        data_set,
        repos_list_2,
        ["push", "pull_request", "target_pull_request", "schedule", "workflow_dispatch", "release", "workflow_run"],
    )
    rest_1 = ru.get_avg_runtime_rest(
        data_set,
        repos_list_1,
        ["push", "pull_request", "target_pull_request", "schedule", "workflow_dispatch", "release", "workflow_run"],
    )

    c5 = rest_1[0]
    c6 = rest_1[-1]
    c7 = rest_2[0]
    c8 = rest_2[-1]
    return 100 - c1, 100 - c2, 100 - c3, 100 - c4, c5, c6, c7, c8

def row_for_event(event_key: str, label: str):
    vm_paid = round(time_prop_1.get(event_key, 0.0), 1)
    vm_free = round(time_prop_2.get(event_key, 0.0), 1)
    runs_paid = round(runs_prop_1.get(event_key, 0.0), 1)
    runs_free = round(runs_prop_2.get(event_key, 0.0), 1)

    mean1, _, _, iqr1 = avg_time_1[event_key]
    mean2, _, _, iqr2 = avg_time_2[event_key]

    cost_paid = round(ru.calc_costs_by_event(mean1, event_key), 2)
    cost_free = round(ru.calc_costs_by_event(mean2, event_key), 2)

    return {
        "label": label,
        "vm_paid": vm_paid,
        "vm_free": vm_free,
        "runs_paid": runs_paid,
        "runs_free": runs_free,
        "mean1": mean1,
        "iqr1": iqr1,
        "mean2": mean2,
        "iqr2": iqr2,
        "cost_paid": cost_paid,
        "cost_free": cost_free,
    }

events_order = [
    ("pull_request", "Pull Request"),
    ("push", "Push"),
    ("schedule", "Schedule"),
    ("pull_request_target", "PR target"),
    ("workflow_dispatch", "Dispatch"),
    ("workflow_run", "Workflow run"),
    ("release", "Release"),
]

rows = [row_for_event(k, lbl) for k, lbl in events_order]

others_vals = calc_others()
others_mean_paid, others_iqr_paid = others_vals[4], others_vals[5]
others_mean_free, others_iqr_free = others_vals[6], others_vals[7]
others_cost_paid = round(ru.calc_costs_by_event(others_mean_paid, "Others"), 2)
others_cost_free = round(ru.calc_costs_by_event(others_mean_free, "Others"), 2)

rows.append(
    {
        "label": "Others",
        "vm_paid": others_vals[0],
        "vm_free": others_vals[1],
        "runs_paid": others_vals[2],
        "runs_free": others_vals[3],
        "mean1": others_mean_paid,
        "iqr1": others_iqr_paid,
        "mean2": others_mean_free,
        "iqr2": others_iqr_free,
        "cost_paid": others_cost_paid,
        "cost_free": others_cost_free,
    }
)

# Output in the same markdown-table structure as expected.md
print("**Table 1: Summary of resource usage by triggering event.**")
print()
print("| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |")
print("| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |")

for r in rows:
    vm_paid_str = f"{r['vm_paid']:.1f}"
    vm_free_str = f"{r['vm_free']:.1f}"
    runs_paid_str = f"{r['runs_paid']:.1f}"
    runs_free_str = f"{r['runs_free']:.1f}"
    paid_time_str = f"{r['mean1']:.1f} ({r['iqr1']:.1f})"
    free_time_str = f"{r['mean2']:.1f} ({r['iqr2']:.1f})"
    cost_paid_str = f"{r['cost_paid']:.2f}"
    cost_free_str = f"{r['cost_free']:.2f}"

    # Special-case formatting for the Workflow run free cost cell (<0.01)
    if r["label"] == "Workflow run" and r["cost_free"] < 0.01:
        cost_free_str = "<0.01"

    print(
        f"| {r['label']:<12} | {vm_paid_str:>15} | {vm_free_str:>15} | "
        f"{runs_paid_str:>12} | {runs_free_str:>12} | "
        f"{paid_time_str:>26} | {free_time_str:>26} | "
        f"{cost_paid_str:>24} | {cost_free_str:>24} |"
    )

print()
print("* mean (inter-quartile range)")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
