#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=3) | 4.5% (0.0%) of all runs<br>17.2% (1.0%) of scheduled runs | 3.2% (0.0%) of all runs time<br>21.3% (4.9%) of scheduled runs time  |                         -125.72 (-1.55) |
| Deactivate scheduled workflows during repository inactivity       | 4.5% (0.6%) of all runs<br>17.1% (1.4%) of scheduled runs | 0.0% (0.0%) of all runs time<br>0.1% (0.1%) of scheduled runs time   |                          -99.78 (-3.81) |
| Run previously failed jobs first                                  | 1.0% (0.8%) of all runs<br>29.5% (7.7%) of failed runs    | 1.1% (0.0%) of all runs time<br>31.6% (45.3%) of failed runs time    |                          -17.89 (-0.77) |
| Project-specific timeouts                                         | 0.5% (0.0%) of all runs                                   | 3.5% (2.2%) of all runs time                                         |                        -173.71 (-47.49) |

* measurement for paid tier (measurement for free tier)

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
pip install -r /workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization/requirements.txt && pip install nbformat
python - <<'EOPY'
import sys
from pathlib import Path
import nbformat

base = Path("/workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization")
sys.path.append(str(base / "src"))

nb_path = base / "paper_analysis_RQ3.ipynb"
nb = nbformat.read(nb_path, as_version=4)

env: dict = {}
for cell in nb.cells:
    if cell.get("cell_type") != "code":
        continue
    src = cell.get("source", "")
    lines = []
    for ln in src.splitlines():
        s = ln.strip()
        if s.startswith("%") or s.startswith("!"):
            # skip notebook magics and shell escapes
            continue
        lines.append(ln)
    code = "\n".join(lines).strip()
    if not code:
        continue
    exec(compile(code, str(nb_path), "exec"), env, env)

optimizations = env.get("optimizations")
if optimizations is None:
    raise SystemExit("optimizations dict not found after executing RQ3 notebook code.")

def val_to_pct(v):
    try:
        x = float(v)
    except Exception:
        return 0.0
    # Heuristic: if <=1, treat as fraction and convert to percentage
    if abs(x) <= 1.0:
        x *= 100.0
    return round(x, 1)

def fmt_impacted(all_p, all_f, subset_p=None, subset_f=None, subset_label="scheduled"):
    line_all = f"{val_to_pct(all_p)}% ({val_to_pct(all_f)}%) of all runs"
    if subset_p is None or subset_f is None:
        return line_all, ""
    line_sub = f"{val_to_pct(subset_p)}% ({val_to_pct(subset_f)}%) of {subset_label} runs"
    return line_all, line_sub

def fmt_time(all_p, all_f, subset_p=None, subset_f=None, subset_label="scheduled"):
    line_all = f"{val_to_pct(all_p)}% ({val_to_pct(all_f)}%) of all runs time"
    if subset_p is None or subset_f is None:
        return line_all, ""
    line_sub = f"{val_to_pct(subset_p)}% ({val_to_pct(subset_f)}%) of {subset_label} runs time"
    return line_all, line_sub

def fmt_cost(paid_cost, free_cost):
    # saved_cost is positive amount of savings; Table shows negative deltas
    return f"-{abs(float(paid_cost)):.2f} (-{abs(float(free_cost)):.2f})"

lines = []
lines.append("**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**")
lines.append("")
lines.append("| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |")
lines.append("| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |")

# 1) Deactivate scheduled workflows after k consecutive failures (k=3)
o_ws = optimizations["wasted_schedule"]
p_ws = o_ws["paid"]
f_ws = o_ws["free"]
imp_all_1, imp_sub_1 = fmt_impacted(p_ws["all_runs"], f_ws["all_runs"], p_ws["subset_runs"], f_ws["subset_runs"], subset_label="scheduled")
time_all_1, time_sub_1 = fmt_time(p_ws["saved_time_all"], f_ws["saved_time_all"], p_ws["saved_subset"], f_ws["saved_subset"], subset_label="scheduled")
cost_1 = fmt_cost(p_ws["saved_cost"], f_ws["saved_cost"])
lines.append(f"| Deactivate scheduled workflows after k consecutive failures (k=3) | {imp_all_1}<br>{imp_sub_1} | {time_all_1}<br>{time_sub_1}  |                         {cost_1} |")

# 2) Deactivate scheduled workflows during repository inactivity
o_ws2 = optimizations["wasted_schedule_2"]
p_ws2 = o_ws2["paid"]
f_ws2 = o_ws2["free"]
imp_all_2, imp_sub_2 = fmt_impacted(p_ws2["all_runs"], f_ws2["all_runs"], p_ws2["subset_runs"], f_ws2["subset_runs"], subset_label="scheduled")
time_all_2, time_sub_2 = fmt_time(p_ws2["saved_time_all"], f_ws2["saved_time_all"], p_ws2["saved_subset"], f_ws2["saved_subset"], subset_label="scheduled")
cost_2 = fmt_cost(p_ws2["saved_cost"], f_ws2["saved_cost"])
lines.append(f"| Deactivate scheduled workflows during repository inactivity       | {imp_all_2}<br>{imp_sub_2} | {time_all_2}<br>{time_sub_2}   |                          {cost_2} |")

# 3) Run previously failed jobs first
o_fj = optimizations["failed_jobs"]
p_fj = o_fj["paid"]
f_fj = o_fj["free"]
imp_all_3, imp_sub_3 = fmt_impacted(p_fj["all_runs"], f_fj["all_runs"], p_fj["subset_runs"], f_fj["subset_runs"], subset_label="failed")
# Notebook divides by 100 to convert from per-impacted to per-all; replicate that behavior
time_all_3, time_sub_3 = fmt_time(p_fj["saved_time_all"] / 100.0, f_fj["saved_time_all"] / 100.0,
                                  p_fj["saved_subset"] / 100.0, f_fj["saved_subset"] / 100.0,
                                  subset_label="failed")
cost_3 = fmt_cost(p_fj["saved_cost"], f_fj["saved_cost"])
lines.append(f"| Run previously failed jobs first                                  | {imp_all_3}<br>{imp_sub_3}    | {time_all_3}<br>{time_sub_3}    |                          {cost_3} |")

# 4) Project-specific timeouts
o_to = optimizations["vm_timeout"]
p_to = o_to["paid"]
f_to = o_to["free"]
imp_all_4, _ = fmt_impacted(p_to["all_runs"], f_to["all_runs"])
time_all_4, _ = fmt_time(p_to["saved_time_all"], f_to["saved_time_all"])
cost_4 = fmt_cost(p_to["saved_cost"], f_to["saved_cost"])
lines.append(f"| Project-specific timeouts                                         | {imp_all_4}                                   | {time_all_4}                                         |                        {cost_4} |")

lines.append("")
lines.append("* measurement for paid tier (measurement for free tier)")
lines.append("")

Path("/workspace/repro.txt").write_text("\n".join(lines), encoding="utf-8")
EOPY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
