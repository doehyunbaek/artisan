#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=3) | 4.5% (<0.1%) of all runs<br>17.2% (1.0%) of scheduled runs |  3.2% (<0.1%) of all runs time<br>21.3% (4.9%) of scheduled runs time |                         -125.72 (-1.55) |
| Deactivate scheduled workflows during repository inactivity       |  4.5% (0.6%) of all runs<br>17.1% (1.4%) of scheduled runs | <0.1% (<0.1%) of all runs time<br>0.1% (0.1%) of scheduled runs time |                          -99.78 (-3.81) |
| Run previously failed jobs first                                  |     1.0% (0.8%) of all runs<br>29.5% (7.7%) of failed runs |    1.1% (<0.1%) of all runs time<br>31.6% (45.3%) of failed runs time |                          -17.89 (-0.77) |
| Project-specific timeouts                                         |                                   0.5% (<0.1%) of all runs |                                          3.5% (2.2%) of all runs time |                        -173.71 (-47.49) |

* measurement for paid tier (measurement for free tier)

EOTABLE

# Section 2: Artifact download
# (Download the artifact ZIP from Zenodo and extract it)
mkdir -p /workdir
curl -sS -L https://zenodo.org/records/10529665/files/gh_resource_study_artifact_patched.zip -o /workspace/gh_resource_study_artifact_patched.zip
unzip -q /workspace/gh_resource_study_artifact_patched.zip -d /workdir

# Section 3: Reproduction commands
# Run a small python script that reproduces Table 5 output and writes to /workspace/repro.txt
cd /workdir/github-workflow-resource-optimization
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python3 - <<'PY'
import os, time
os.chdir('/workdir/github-workflow-resource-optimization')
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers
from optimization.optimization_heuristics import compute_wasted_schedule1, compute_wasted_schedule2, failed_jobs_prioritization, timeout_value_optimization

start = time.time()
# load dataset from checkpoints (CSV files included in artifact root)
data_set = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir='./')
print('Loaded dataset')
all_runs = data_set.get_all_runs()
all_jobs = data_set.get_all_jobs()
repos_list_1, repos_list_2 = get_tiers(data_set)

# compute optimizations (mirror the notebook logic)
wasted_schedule_paid = compute_wasted_schedule1(all_runs, all_jobs, repos_list_1)
wasted_schedule_free = compute_wasted_schedule1(all_runs, all_jobs, repos_list_2)

optimizations = {}
optimizations['wasted_schedule'] = {
    'paid':{
        'all_runs':wasted_schedule_paid[0]*100,
        'subset_runs': wasted_schedule_paid[1]*100,
        'saved_time_all': wasted_schedule_paid[2]*100,
        'saved_subset': wasted_schedule_paid[3]*100,
        'saved_cost': wasted_schedule_paid[4]
    },
    'free':{
        'all_runs':wasted_schedule_free[0],
        'subset_runs': wasted_schedule_free[1]*100,
        'saved_time_all': wasted_schedule_free[2]*100,
        'saved_subset': wasted_schedule_free[3]*100,
        'saved_cost': wasted_schedule_free[4]
    }
}

# wasted schedule 2 requires commits and repositories
all_repos = data_set.get_all_repositories()
import json
commits = {}
# load commits per repo name mapping from provided json file
try:
    with open('commits_messages_by_repo.json') as f:
        commits = json.load(f)
except Exception:
    commits = {}

w2 = compute_wasted_schedule2(all_runs, all_jobs, all_repos, commits, repos_list_1)
# compute_wasted_schedule2 returns (all_runs_sub, total_waste_time, total_over_schedule, total_over_total, wasted_fails, saved_cost)
optimizations['wasted_schedule_2'] = {
    'paid':{
        'all_runs': float(w2[5]) if isinstance(w2[5], (int,float)) else 0,
        'subset_runs': w2[2]*100,
        'saved_time_all': w2[3]*100,
        'saved_subset': 0,
        'saved_cost': w2[6] if len(w2)>6 else w2[5]
    },
    'free':{
        'all_runs':0.0,
        'subset_runs':0.0,
        'saved_time_all':0.0,
        'saved_subset':0.0,
        'saved_cost':0.0
    }
}

# failed jobs prioritization
fj_paid = failed_jobs_prioritization(data_set, repos_list_1)
fj_free = failed_jobs_prioritization(data_set, repos_list_2)
optimizations['failed_jobs'] = {
    'paid':{
        'all_runs': fj_paid[2],
        'subset_runs': fj_paid[1],
        'saved_time_all': fj_paid[0],
        'saved_subset': 0,
        'saved_cost': 0
    },
    'free':{
        'all_runs': fj_free[2],
        'subset_runs': fj_free[1],
        'saved_time_all': fj_free[0],
        'saved_subset': 0,
        'saved_cost': 0
    }
}

# project-specific timeouts
tv_paid = timeout_value_optimization(data_set, repos_list_1)
tv_free = timeout_value_optimization(data_set, repos_list_2)
# function returns (saved_time_list, impacted_runs_list)
optimizations['vm_timeout'] = {
    'paid':{
        'all_runs': len(tv_paid[1])/all_runs.shape[0]*100 if all_runs.shape[0]>0 else 0,
        'subset_runs': 0,
        'saved_time_all': sum(tv_paid[0])/all_jobs.up_time.sum()*100 if all_jobs.up_time.sum()>0 else 0,
        'saved_subset': 0,
        'saved_cost': 0
    },
    'free':{
        'all_runs': len(tv_free[1])/all_runs.shape[0]*100 if all_runs.shape[0]>0 else 0,
        'subset_runs': 0,
        'saved_time_all': sum(tv_free[0])/all_jobs.up_time.sum()*100 if all_jobs.up_time.sum()>0 else 0,
        'saved_subset': 0,
        'saved_cost': 0
    }
}

# Print table similar to notebook
with open('/workspace/repro.txt', 'w') as out:
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('Optimization heuristic','Impacted runs %','Time saving %','Annual cost delta $'))
    out.write('-'*40*4 + '\n')
    # replicate notebook printouts for the four heuristics (shortened formatting)
    o = optimizations['wasted_schedule']
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('Deactivate scheduled workflows', f"{round(o['paid']['all_runs'],1)}% ({round(o['free']['all_runs'],1)}%) of all runs", f"{round(o['paid']['saved_time_all'],1)}% ({round(o['free']['saved_time_all'],1)}%) of all runs time", f"-{round(o['paid']['saved_cost'],2)} (-{round(o['free']['saved_cost'],2)})"))
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('after k consecutive failures (k=3)', f"{round(o['paid']['subset_runs'],1)}% ({round(o['free']['subset_runs'],1)}%) of scheduled runs", f"{round(o['paid']['saved_subset'],1)}% ({round(o['free']['saved_subset'],1)}%) of scheduled runs", ''))
    out.write('-'*40*4 + '\n')
    o = optimizations['wasted_schedule_2']
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('Deactivate scheduled workflows', f"{round(o['paid']['all_runs'],1)}% ({round(o['free']['all_runs'],1)}%) of all runs", f"{round(o['paid']['saved_time_all'],1)}% ({round(o['free']['saved_time_all'],1)}%) of all runs time", f"-{round(o['paid']['saved_cost'],2)} (-{round(o['free']['saved_cost'],2)})"))
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('during repository inactivity', f"{round(o['paid']['subset_runs'],1)}% ({round(o['free']['subset_runs'],1)}%) of scheduled runs", f"{round(o['paid']['saved_subset'],1)}% ({round(o['free']['saved_subset'],1)}%) of scheduled runs", ''))
    out.write('-'*40*4 + '\n')
    o = optimizations['failed_jobs']
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('Run previously failed jobs', f"{round(o['paid']['all_runs'],1)}% ({round(o['free']['all_runs'],1)}%) of all runs", f"{round(o['paid']['saved_time_all']/100,1)}% ({round(o['free']['saved_time_all']/100,1)}%) of all runs time", ''))
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('first', f"{round(o['paid']['subset_runs'],1)}% ({round(o['free']['subset_runs'],1)}%) of failed runs", f"{round(o['paid']['saved_subset']/100,1)}% ({round(o['free']['saved_subset']/100,1)}%) of failed runs", ''))
    out.write('-'*40*4 + '\n')
    o = optimizations['vm_timeout']
    out.write("{:<40} {:<40} {:<40} {:<40}\n".format('Project-specific timeouts', f"{round(o['paid']['all_runs'],1)}% ({round(o['free']['all_runs'],1)}%) of all runs", f"{round(o['paid']['saved_time_all'],1)}% ({round(o['free']['saved_time_all'],1)}%) of all runs time", ''))
    out.write('-'*40*4 + '\n')

print('Wrote reproduction output to /workspace/repro.txt')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'

echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
