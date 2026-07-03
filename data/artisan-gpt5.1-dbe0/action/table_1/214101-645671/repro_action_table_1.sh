#!/usr/bin/bash
set -euo pipefail

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

# Load the Docker image that is part of the artifact
IMAGE=$(docker image load -i gh_resource_study_artifact_patched/github-workflow-resource-optimization/github_study_container_patched.tar | awk '/Loaded image:/ {print $3}' | tail -n 1)

# Start a long-running container from that image
CID=$(docker run -d --init --entrypoint bash "$IMAGE" -c 'sleep infinity')

# Create the Python script that reproduces Table 1 inside the container
cat > /workspace/gen_table1.py <<'PY'
import io
import sys
import time

from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import (
    triggering_events_proportion,
    triggering_events_time_proportion,
    get_avg_runtime_by_event,
    get_tiers,
    calc_costs_by_event as calc_costs,
    get_avg_runtime_rest,
)

# Suppress internal prints from RunsDataSet (e.g., "Loading dataset from checkpoints")
old_stdout = sys.stdout
sys.stdout = io.StringIO()
workdir = "/workdir/"
start = time.time()
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=workdir)
end = time.time()
sys.stdout = old_stdout

repos_list_1, repos_list_2 = get_tiers(data_set)
runs_prop_1 = triggering_events_proportion(data_set, repos_list_1)
runs_prop_2 = triggering_events_proportion(data_set, repos_list_2)
time_prop_1 = triggering_events_time_proportion(data_set, repos_list_1)
time_prop_2 = triggering_events_time_proportion(data_set, repos_list_2)
avg_time_1 = get_avg_runtime_by_event(data_set, repos_list_1)
avg_time_2 = get_avg_runtime_by_event(data_set, repos_list_2)

def fmt_pct(v: float) -> str:
    return f"{round(v, 1):.1f}"

def fmt_time(v: float) -> str:
    return f"{round(v, 1):.1f}"

def fmt_cost(v: float) -> str:
    return f"{round(v, 2):.2f}"

event_labels = [
    ("pull_request", "Pull Request"),
    ("push", "Push"),
    ("schedule", "Schedule"),
    ("pull_request_target", "PR target"),
    ("workflow_dispatch", "Dispatch"),
    ("workflow_run", "Workflow run"),
    ("release", "Release"),
]

rows = []

for event, label in event_labels:
    vm_time_paid = fmt_pct(time_prop_1[event])
    vm_time_free = fmt_pct(time_prop_2[event])
    runs_paid = fmt_pct(runs_prop_1[event])
    runs_free = fmt_pct(runs_prop_2[event])
    mean_paid = fmt_time(avg_time_1[event][0])
    iqr_paid = fmt_time(avg_time_1[event][-1])
    mean_free = fmt_time(avg_time_2[event][0])
    iqr_free = fmt_time(avg_time_2[event][-1])
    cost_paid = fmt_cost(calc_costs(avg_time_1[event][0], event))
    cost_free = fmt_cost(calc_costs(avg_time_2[event][0], event))

    row = (
        f"| {label} | {vm_time_paid:>13} | {vm_time_free:>13} | "
        f"{runs_paid:>11} | {runs_free:>11} | "
        f"{mean_paid} ({iqr_paid}) | {mean_free} ({iqr_free}) | "
        f"{cost_paid:>6} | {cost_free:>6} |"
    )
    rows.append(row)

# Compute the "Others" row as in the notebook
c1 = c2 = c3 = c4 = 0.0
for ev in ["pull_request", "push", "schedule", "pull_request_target", "workflow_dispatch", "workflow_run", "release"]:
    c1 += round(time_prop_1[ev], 1)
    c2 += round(time_prop_2[ev], 1)
    c3 += round(runs_prop_1[ev], 1)
    c4 += round(runs_prop_2[ev], 1)

rest_2 = get_avg_runtime_rest(
    data_set,
    repos_list_2,
    ["push", "pull_request", "target_pull_request", "schedule", "workflow_dispatch", "release", "workflow_run"],
)
rest_1 = get_avg_runtime_rest(
    data_set,
    repos_list_1,
    ["push", "pull_request", "target_pull_request", "schedule", "workflow_dispatch", "release", "workflow_run"],
)

vm_time_paid_others = fmt_pct(100 - c1)
vm_time_free_others = fmt_pct(100 - c2)
runs_paid_others = fmt_pct(100 - c3)
runs_free_others = fmt_pct(100 - c4)
mean_paid_others = fmt_time(rest_1[0])
iqr_paid_others = fmt_time(rest_1[-1])
mean_free_others = fmt_time(rest_2[0])
iqr_free_others = fmt_time(rest_2[-1])
cost_paid_others = fmt_cost(calc_costs(rest_1[0], "others"))
cost_free_others = fmt_cost(calc_costs(rest_2[0], "others"))

others_row = (
    f"| Others       | {vm_time_paid_others:>13} | {vm_time_free_others:>13} | "
    f"{runs_paid_others:>11} | {runs_free_others:>11} | "
    f"{mean_paid_others} ({iqr_paid_others}) | {mean_free_others} ({iqr_free_others}) | "
    f"{cost_paid_others:>6} | {cost_free_others:>6} |"
)
rows.append(others_row)

# Emit the final Markdown table
print("**Table 1: Summary of resource usage by triggering event.**")
print()
print("| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |")
print("| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |")
for row in rows:
    print(row)
print()
print("* mean (inter-quartile range)")
PY

# Copy the Python script into the container and run it to generate /workspace/repro.txt
docker cp /workspace/gen_table1.py "$CID":/workdir/gen_table1.py
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /workdir && PYTHONPATH=/workdir/src python gen_table1.py" > /workspace/repro.txt

# Clean up temporary script and container
rm -f /workspace/gen_table1.py
docker rm -f "$CID" >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
