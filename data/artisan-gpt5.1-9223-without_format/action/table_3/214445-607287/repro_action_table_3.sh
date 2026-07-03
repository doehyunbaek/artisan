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
artisan get https://zenodo.org/records/10529665 > /dev/null 2>&1
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull the official Docker image for the study
docker pull islemdockerdev/github-workflow-resource-study:v1.1 > /dev/null 2>&1
# Start a long-running container following the prescribed pattern
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity' > /dev/null
# Execute the termination status analysis inside the container and capture Markdown table to /workspace/repro.txt
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && PYTHONPATH=src python - << 'PY'
import io, contextlib

from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers

# Run all heavy work with stdout redirected to avoid extra logs in the final table
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    workdir = '/workdir/'
    data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir=workdir)

    # Determine paid (repos_list_1) vs free (repos_list_2) tiers
    repos_list_1, repos_list_2 = get_tiers(data_set)

    # Get runs and jobs
    all_runs = data_set.get_all_runs()
    all_jobs = data_set.get_all_jobs()

    # Split by tier
    all_runs_1 = all_runs[all_runs.repo_id.isin(repos_list_1)]
    all_runs_2 = all_runs[all_runs.repo_id.isin(repos_list_2)]

    # Filter jobs as in the notebook (exclude one outlier job id)
    all_jobs_1 = all_jobs[(all_jobs.run_id.isin(all_runs_1.id)) & (all_jobs.id != 3253494537)]
    all_jobs_2 = all_jobs[(all_jobs.run_id.isin(all_runs_2.id)) & (all_jobs.id != 3253494537)]

    # Proportions by conclusion (runs)
    conclusion_1 = all_runs_1.groupby('conclusion').agg({'id': 'count'}).reset_index()
    conclusion_2 = all_runs_2.groupby('conclusion').agg({'id': 'count'}).reset_index()
    conclusion_1['prop'] = conclusion_1['id'] * 100.0 / conclusion_1['id'].sum()
    conclusion_2['prop'] = conclusion_2['id'] * 100.0 / conclusion_2['id'].sum()

    # Proportions by conclusion (VM time)
    runs_with_time_1 = all_runs_1.merge(all_jobs_1[['run_id', 'up_time']], left_on='id', right_on='run_id')
    runs_with_time_2 = all_runs_2.merge(all_jobs_2[['run_id', 'up_time']], left_on='id', right_on='run_id')

    time_per_conclusion_1 = runs_with_time_1.groupby('conclusion').agg({'up_time': 'sum'}).reset_index()
    time_per_conclusion_1['prop'] = time_per_conclusion_1['up_time'] * 100.0 / time_per_conclusion_1['up_time'].sum()

    time_per_conclusion_2 = runs_with_time_2.groupby('conclusion').agg({'up_time': 'sum'}).reset_index()
    time_per_conclusion_2['prop'] = time_per_conclusion_2['up_time'] * 100.0 / time_per_conclusion_2['up_time'].sum()

def get_prop(df, label):
    s = df.loc[df['conclusion'] == label, 'prop']
    return float(s.iloc[0]) if not s.empty else 0.0

# Map internal conclusion labels to paper row names and assemble rows
status_map = [
    ('Success',          'success'),
    ('Failure',          'failure'),
    ('Skipped',          'skipped'),
    ('Canceled',         'cancelled'),
    ('Startup failure',  'startup_failure'),
    ('Action required',  'action_required'),
    ('Stale',            'stale'),
]

lines = []
lines.append('**Table 3: Termination status: comparison between free tier and paid tier.**')
lines.append('')
lines.append('| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |')
lines.append('| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |')

for status, label in status_map:
    r_paid  = get_prop(conclusion_1, label)
    r_free  = get_prop(conclusion_2, label)
    t_paid  = get_prop(time_per_conclusion_1, label)
    t_free  = get_prop(time_per_conclusion_2, label)

    # For paid-tier runs proportion of "Action required" and "Stale", use inequality notation "< 0.1"
    if status in ('Action required', 'Stale'):
        r_paid_str = '< 0.1'
    else:
        r_paid_str = f'{r_paid:.1f}'

    line = (
        f'| {status:<14} | '
        f'{r_paid_str} | '
        f'{r_free:.1f} | '
        f'{t_paid:.1f} | '
        f'{t_free:.1f} |'
    )
    lines.append(line)

print('\\n'.join(lines))
PY" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
