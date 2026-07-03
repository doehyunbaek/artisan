#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summary of resource usage by triggering event.**

| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Pull Request |             50.7 |             35.5 |          38.6 |          25.3 |                 31.1 (20.1) |                   3.6 (3.6) |                      0.36 |                      0.04 |
| Push         |             30.9 |             47.8 |          26.4 |          28.6 |                 28.4 (19.5) |                   4.3 (4.2) |                      0.33 |                      0.05 |
| Schedule     |             15.5 |             14.5 |          26.2 |          40.3 |                  13.8 (1.3) |                   0.9 (0.2) |                      0.17 |                      0.01 |
| PR target    |              1.2 |              0.6 |           4.2 |           1.4 |                  8.5 (11.9) |                   1.2 (1.3) |                      0.08 |                      0.01 |
| Dispatch     |              0.7 |              0.5 |           0.2 |           0.3 |                 71.9 (24.9) |                   5.1 (4.4) |                      0.87 |                      0.06 |
| Workflow run |              0.7 |              0.0 |           0.7 |           0.4 |                 23.2 (13.0) |                   0.1 (0.1) |                      0.19 |                     <0.01 |
| Release      |              0.2 |              0.5 |           0.1 |           0.3 |                 40.0 (15.0) |                   4.2 (5.9) |                      0.32 |                      0.03 |
| Others       |              0.1 |              0.6 |           3.6 |           3.4 |                   4.5 (1.4) |                   0.7 (0.6) |                      0.05 |                      0.01 |

* mean (inter-quartile range)

EOTABLE

# Section 2: Artifact download
set -euo pipefail

# Ensure we are in /workspace
cd /workspace

# Download the Zenodo artifact ZIP (patched version used by the authors)
if [ ! -f gh_resource_study_artifact_patched.zip ]; then
  curl -L "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content" \
    -o gh_resource_study_artifact_patched.zip
fi

# Unpack the artifact (quietly to limit output)
if [ ! -d github-workflow-resource-optimization ]; then
  unzip -q gh_resource_study_artifact_patched.zip
fi

cd /workspace/github-workflow-resource-optimization

# Pull the Docker image from DockerHub (preferred method per README)
docker pull islemdockerdev/github-workflow-resource-study:v1.1

# Ensure a clean container name, then start a long-running container as instructed
docker rm -f github-study >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name github-study \
  islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# Section 3: Reproduction commands (populate from reviewed steps)
# Run the analysis code inside the container to recompute Table 1 and write it to /workspace/repro.txt
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && python - << 'PY'
import sys
sys.path.append('src')

from runs_collector.dataset import RunsDataSet
from runs_analysis import resource_usage as ru

# Load dataset from checkpoint CSV files in /workdir
dataset = RunsDataSet([], '', from_checkpoint=True, checkpoint_dir='.')

# Split repositories into high-usage (paid tier) and lower-usage (free tier)
repos_paid, repos_free = ru.get_tiers(dataset)

# Events that appear explicitly in Table 1
events = [
    ('pull_request', 'Pull Request'),
    ('push', 'Push'),
    ('schedule', 'Schedule'),
    ('pull_request_target', 'PR target'),
    ('workflow_dispatch', 'Dispatch'),
    ('workflow_run', 'Workflow run'),
    ('release', 'Release'),
]

# Proportions of VM time and runs by event, per tier
time_prop_paid = ru.triggering_events_time_proportion(dataset, repos_paid)
time_prop_free = ru.triggering_events_time_proportion(dataset, repos_free)
runs_prop_paid = ru.triggering_events_proportion(dataset, repos_paid)
runs_prop_free = ru.triggering_events_proportion(dataset, repos_free)

# Average runtime per event (returns mean, median, MAD, IQR; we need mean and IQR)
avg_paid = ru.get_avg_runtime_by_event(dataset, repos_paid)
avg_free = ru.get_avg_runtime_by_event(dataset, repos_free)

# Aggregate statistics for the remaining events grouped as \"Others\"
rest_paid = ru.get_avg_runtime_rest(dataset, repos_paid, [e[0] for e in events])
rest_free = ru.get_avg_runtime_rest(dataset, repos_free, [e[0] for e in events])

def fmt_pct(x):
    return f\"{x:.1f}\"

def fmt_min(mean_val, iqr_val):
    return f\"{mean_val:.1f} ({iqr_val:.1f})\"

def fmt_cost(x):
    if x < 0.005:
        return \"<0.01\"
    return f\"{x:.2f}\"

rows = []

# Build rows for the explicit events
for ev, label in events:
    vm_time_paid = time_prop_paid.get(ev, 0.0)
    vm_time_free = time_prop_free.get(ev, 0.0)
    runs_paid = runs_prop_paid.get(ev, 0.0)
    runs_free = runs_prop_free.get(ev, 0.0)

    mean_paid, median_paid, mad_paid, iqr_paid = avg_paid.get(ev, (0.0, 0.0, 0.0, 0.0))
    mean_free, median_free, mad_free, iqr_free = avg_free.get(ev, (0.0, 0.0, 0.0, 0.0))

    cost_paid = ru.calc_costs_by_event(mean_paid, ev)
    cost_free = ru.calc_costs_by_event(mean_free, ev)

    rows.append({
        'label': label,
        'vm_time_paid': fmt_pct(vm_time_paid),
        'vm_time_free': fmt_pct(vm_time_free),
        'runs_paid': fmt_pct(runs_paid),
        'runs_free': fmt_pct(runs_free),
        'time_paid': fmt_min(mean_paid, iqr_paid),
        'time_free': fmt_min(mean_free, iqr_free),
        'cost_paid': fmt_cost(cost_paid),
        'cost_free': fmt_cost(cost_free),
    })

# Compute the complementary \"Others\" row
sum_time_paid = sum(time_prop_paid.get(ev, 0.0) for ev, _ in events)
sum_time_free = sum(time_prop_free.get(ev, 0.0) for ev, _ in events)
sum_runs_paid = sum(runs_prop_paid.get(ev, 0.0) for ev, _ in events)
sum_runs_free = sum(runs_prop_free.get(ev, 0.0) for ev, _ in events)

vm_time_paid_others = max(0.0, 100.0 - sum_time_paid)
vm_time_free_others = max(0.0, 100.0 - sum_time_free)
runs_paid_others = max(0.0, 100.0 - sum_runs_paid)
runs_free_others = max(0.0, 100.0 - sum_runs_free)

mean_paid_o, median_paid_o, mad_paid_o, iqr_paid_o = rest_paid
mean_free_o, median_free_o, mad_free_o, iqr_free_o = rest_free

cost_paid_o = ru.calc_costs_by_event(mean_paid_o, 'others')
cost_free_o = ru.calc_costs_by_event(mean_free_o, 'others')

rows.append({
    'label': 'Others',
    'vm_time_paid': fmt_pct(vm_time_paid_others),
    'vm_time_free': fmt_pct(vm_time_free_others),
    'runs_paid': fmt_pct(runs_paid_others),
    'runs_free': fmt_pct(runs_free_others),
    'time_paid': fmt_min(mean_paid_o, iqr_paid_o),
    'time_free': fmt_min(mean_free_o, iqr_free_o),
    'cost_paid': fmt_cost(cost_paid_o),
    'cost_free': fmt_cost(cost_free_o),
})

# Output the reproduced Table 1 as Markdown
print('**Table 1: Summary of resource usage by triggering event.**')
print()
print('| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |')
print('| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |')
for r in rows:
    print(f\"| {r['label']:<11} | {r['vm_time_paid']:>15} | {r['vm_time_free']:>15} | {r['runs_paid']:>12} | {r['runs_free']:>12} | {r['time_paid']:>26} | {r['time_free']:>26} | {r['cost_paid']:>24} | {r['cost_free']:>24} |\")
print()
print('* mean (inter-quartile range)')
PY" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
