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
| Startup failure |                      ?.? |                      ?.? |                         ?.? |                         ??.? |
| Action required |                    < ?.? |                      ?.? |                         ?.? |                         ?.? |
| Stale           |                    < ?.? |                      ?.? |                         ?.? |                         ??.? |

EOTABLE

# Section 2: Ensure artifact present
artisan get https://zenodo.org/records/10529665 || true

# Section 3: Recompute Table 3 from raw CSVs using only Python stdlib
python3 - <<'PY' > /workspace/repro.txt
import csv, json, ast, sys, os, re

base = "gh_resource_study_artifact_patched/github-workflow-resource-optimization"
nb_path = os.path.join(base, "paper_analysis_RQ1.ipynb")

def try_extract_lists_from_notebook(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            nb = json.load(f)
    except Exception:
        return None, None
    repos1 = None
    repos2 = None
    for cell in nb.get("cells", []):
        if cell.get("cell_type") != "code":
            continue
        src = "".join(cell.get("source", []))
        m1 = re.search(r"repos_list_1\s*=\s*(\[[^\]]*\])", src)
        m2 = re.search(r"repos_list_2\s*=\s*(\[[^\]]*\])", src)
        if m1 and repos1 is None:
            try:
                repos1 = ast.literal_eval(m1.group(1))
            except Exception:
                repos1 = None
        if m2 and repos2 is None:
            try:
                repos2 = ast.literal_eval(m2.group(1))
            except Exception:
                repos2 = None
        if repos1 is not None and repos2 is not None:
            break
    return repos1, repos2

def read_repo_ids_csv(path):
    ids = []
    with open(path, 'r', encoding='utf-8') as f:
        r = csv.reader(f)
        hdr = next(r)
        # find candidate id column
        cand_cols = ['id','repo_id','repoId','repoID']
        col_idx = None
        for c in cand_cols:
            if c in hdr:
                col_idx = hdr.index(c)
                break
        if col_idx is None:
            # fallback to first column
            col_idx = 0
        for row in r:
            try:
                v = row[col_idx].strip()
                if v!='':
                    ids.append(int(float(v)))
            except Exception:
                continue
    return ids

# Try to get lists from notebook
repos1, repos2 = try_extract_lists_from_notebook(nb_path)

# Fallback: read repositories CSVs
if not repos1 or not repos2:
    repo1_path = os.path.join(base, "repositories.csv")
    repo2_path = os.path.join(base, "repositories-2021-03-08.csv")
    if os.path.exists(repo1_path) and not repos1:
        repos1 = read_repo_ids_csv(repo1_path)
    if os.path.exists(repo2_path) and not repos2:
        repos2 = read_repo_ids_csv(repo2_path)

if not repos1 or not repos2:
    sys.stderr.write("ERROR: could not determine repos_list_1 and repos_list_2\n")
    sys.exit(2)

repos1_set = set(int(x) for x in repos1 if str(x).strip()!='')
repos2_set = set(int(x) for x in repos2 if str(x).strip()!='')

# Paths to runs and jobs
runs_path = os.path.join(base, "all_runs.csv")
jobs_path = os.path.join(base, "all_jobs.csv")
if not os.path.exists(runs_path) or not os.path.exists(jobs_path):
    sys.stderr.write("ERROR: required CSVs not found\n")
    sys.exit(3)

# We will build:
# - runs_count_1 and runs_count_2 per conclusion
# - run_to_concl_1 and run_to_concl_2 mapping run_id -> conclusion (only for runs in the two groups)
runs_count_1 = {}
runs_count_2 = {}
run_to_concl_1 = {}
run_to_concl_2 = {}

with open(runs_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    # locate columns
    try:
        id_idx = header.index('id')
    except ValueError:
        id_idx = 0
    repo_idx = None
    concl_idx = None
    for c in range(len(header)):
        if header[c] in ('repo_id','repoId','repoID'):
            repo_idx = c
        if header[c]=='conclusion':
            concl_idx = c
    if repo_idx is None:
        # attempt to find second column as repo_id fallback
        repo_idx = 1 if len(header) > 1 else 0
    if concl_idx is None:
        # assume conclusion column exists; else default last column
        concl_idx = len(header)-1
    for row in reader:
        try:
            run_id = int(float(row[id_idx]))
        except Exception:
            continue
        try:
            repo_id = int(float(row[repo_idx]))
        except Exception:
            continue
        conclusion = row[concl_idx].strip() if len(row)>concl_idx else ''
        if repo_id in repos1_set:
            runs_count_1[conclusion] = runs_count_1.get(conclusion, 0) + 1
            run_to_concl_1[run_id] = conclusion
        if repo_id in repos2_set:
            runs_count_2[conclusion] = runs_count_2.get(conclusion, 0) + 1
            run_to_concl_2[run_id] = conclusion

total_runs_1 = sum(runs_count_1.values()) or 1
total_runs_2 = sum(runs_count_2.values()) or 1

# Prepare time sums per conclusion
time_sum_1 = {}
time_sum_2 = {}

exclude_job_id = 3253494537

with open(jobs_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    # locate columns
    try:
        job_id_idx = header.index('id')
    except ValueError:
        job_id_idx = 0
    run_id_idx = None
    up_time_idx = None
    for c in range(len(header)):
        if header[c] in ('run_id',):
            run_id_idx = c
        if header[c] in ('up_time',):
            up_time_idx = c
    if run_id_idx is None:
        run_id_idx = 1 if len(header)>1 else 0
    if up_time_idx is None:
        # attempt to find a numeric column named up_time else last column
        up_time_idx = len(header)-1
    for row in reader:
        try:
            jid = int(float(row[job_id_idx]))
        except Exception:
            continue
        if jid == exclude_job_id:
            continue
        try:
            rid = int(float(row[run_id_idx]))
        except Exception:
            continue
        try:
            up = float(row[up_time_idx]) if row[up_time_idx] != '' else 0.0
        except Exception:
            up = 0.0
        if rid in run_to_concl_1:
            c = run_to_concl_1[rid]
            time_sum_1[c] = time_sum_1.get(c, 0.0) + up
        if rid in run_to_concl_2:
            c = run_to_concl_2[rid]
            time_sum_2[c] = time_sum_2.get(c, 0.0) + up

total_time_1 = sum(time_sum_1.values()) or 1.0
total_time_2 = sum(time_sum_2.values()) or 1.0

# Ordered conclusions
order = ["success", "failure", "skipped", "cancelled", "startup_failure", "action_required", "stale"]

# Compute proportions and format output similar to notebook
lines = []
lines.append("                               Runs proportion %        VM time proportion %")
lines.append("                              --------------------------------------------------")
lines.append("Conclusion                     Paid         Free         Paid         Free        ")
lines.append("--------------------------------------------------------------------------------")
for c in order:
    r1 = round((runs_count_1.get(c,0) * 100.0) / total_runs_1, 1)
    r2 = round((runs_count_2.get(c,0) * 100.0) / total_runs_2, 1)
    t1 = round((time_sum_1.get(c,0.0) * 100.0) / total_time_1, 1)
    t2 = round((time_sum_2.get(c,0.0) * 100.0) / total_time_2, 1)
    lines.append("{:<30} {:<12} {:<12} {:<12} {:<12}".format(c, r1, r2, t1, t2))

sys.stdout.write("\n".join(lines))
PY

# Section 4: Format and submit
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
