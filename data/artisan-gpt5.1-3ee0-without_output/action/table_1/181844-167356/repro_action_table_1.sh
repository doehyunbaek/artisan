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
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
docker exec -w /workdir github-study python3 - << "PY" > /workspace/repro.txt
import time
import os
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import (triggering_events_proportion,
                                          triggering_events_time_proportion,
                                          get_avg_runtime_by_event,
                                          get_tiers,
                                          calc_costs_by_event as calc_costs,
                                          get_avg_runtime_rest)

workdir = "/workdir/"
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=workdir)

repos_list_1, repos_list_2 = get_tiers(data_set)
runs_prop_1 = triggering_events_proportion(data_set, repos_list_1)
runs_prop_2 = triggering_events_proportion(data_set, repos_list_2)
time_prop_1 = triggering_events_time_proportion(data_set, repos_list_1)
time_prop_2 = triggering_events_time_proportion(data_set, repos_list_2)
avg_time_1 = get_avg_runtime_by_event(data_set, repos_list_1)
avg_time_2 = get_avg_runtime_by_event(data_set, repos_list_2)

def calc_others():
    c1 = c2 = c3 = c4 = 0
    for event in ["pull_request", "push", "schedule", "pull_request_target", "workflow_dispatch", "workflow_run", "release"]:
        c1 += round(time_prop_1[event], 1)
        c2 += round(time_prop_2[event], 1)
        c3 += round(runs_prop_1[event], 1)
        c4 += round(runs_prop_2[event], 1)
    rest_2 = get_avg_runtime_rest(data_set, repos_list_2,
                                  ["push", "pull_request", "target_pull_request", "schedule", "workflow_dispatch", "release", "workflow_run"])
    rest_1 = get_avg_runtime_rest(data_set, repos_list_1,
                                  ["push", "pull_request", "target_pull_request", "schedule", "workflow_dispatch", "release", "workflow_run"])
    c5 = rest_1[0]
    c6 = rest_1[-1]
    c7 = rest_2[0]
    c8 = rest_2[-1]
    return 100 - c1, 100 - c2, 100 - c3, 100 - c4, c5, c6, c7, c8

event_display = {
    "pull_request": "Pull Request",
    "push": "Push",
    "schedule": "Schedule",
    "pull_request_target": "PR target",
    "workflow_dispatch": "Dispatch",
    "workflow_run": "Workflow run",
    "release": "Release",
    "others": "Others",
}

def format_vm_time(mean, iqr):
    return f"{round(mean, 1):.1f} ({round(iqr, 1):.1f})"

def format_cost(mean, event):
    return f"{round(calc_costs(mean, event), 2):.2f}"

print("**Table 1: Summary of resource usage by triggering event.**")
print()
print("| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |")
print("| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |")

ordered_events = ["pull_request", "push", "schedule", "pull_request_target", "workflow_dispatch", "workflow_run", "release"]

for ev in ordered_events:
    row = [
        event_display[ev],
        f"{round(time_prop_1[ev], 1):.1f}",
        f"{round(time_prop_2[ev], 1):.1f}",
        f"{round(runs_prop_1[ev], 1):.1f}",
        f"{round(runs_prop_2[ev], 1):.1f}",
        format_vm_time(avg_time_1[ev][0], avg_time_1[ev][-1]),
        format_vm_time(avg_time_2[ev][0], avg_time_2[ev][-1]),
        format_cost(avg_time_1[ev][0], ev),
        format_cost(avg_time_2[ev][0], ev),
    ]
    print("| " + " | ".join(row) + " |")

others = calc_others()
others_row = [
    event_display["others"],
    f"{round(others[0], 1):.1f}",
    f"{round(others[1], 1):.1f}",
    f"{round(others[2], 1):.1f}",
    f"{round(others[3], 1):.1f}",
    format_vm_time(others[4], others[5]),
    format_vm_time(others[6], others[7]),
    format_cost(others[4], "others"),
    format_cost(others[6], "others"),
]
print("| " + " | ".join(others_row) + " |")
print()
print("* mean (inter-quartile range)")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
