#!/usr/bin/bash
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
docker exec github-study /bin/bash --noprofile --norc -c "PYTHONPATH=/workdir/src:/workdir python3 - <<'PY'
import sys
sys.path.insert(0, '/workdir/src')
sys.path.insert(0, '/workdir')
from runs_collector.dataset import RunsDataSet
from runs_analysis.resource_usage import get_tiers
from optimization.optimization_heuristics import get_wasted_schedule_1
# load dataset from checkpoint baked into the image
ds = RunsDataSet(None, None, from_checkpoint=True, checkpoint_dir='/workdir')
all_runs = ds.get_all_runs()
all_jobs = ds.get_all_jobs()
repos_list_1, _ = get_tiers(ds)
all_runs_sub = all_runs[all_runs.repo_id.isin(repos_list_1)]
ks = [1,2,5,10,15,20]
results = []
for k in ks:
    total_waste, waste_over_total_schedule, total_over_total, impacted_runs_schedule, impacted_runs_all, opt_repos = get_wasted_schedule_1(all_runs_sub, all_jobs, k)
    results.append(-round(total_over_total*100,1))
print(' '.join(str(v) for v in results))
PY" > /workspace/repro.txt
echo '<artisan_submit>'
python3 - <<'PY'
vals = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read().split()
vals = [f"{float(v):.1f}" for v in vals[-6:]]  # take the 6 numbers
ks = ["1","2","5","10","15","20"]

print("**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**\n")
print("| k                     |    1 |    2 |    5 |   10 |   15 |   20 |")
print("| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |")
print("| Impact on VM time (%) | " + " | ".join(f"{v:>3}" for v in vals) + " |")
PY
echo '</artisan_submit>'
