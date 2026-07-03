#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Prevalence and impact of workflows optimizations.**

| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |
| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |
| Cache                  | Off      |                   ??.? |                   ??.? |                  ???.? |                  ???.? |                       -?.? |                       -?.? |                            -??.?? |                             -?.?? |
| Fail-fast              | On       |                   ??.? |                   ??.? |                    ?.? |                    ?.? |                       -?.? |                       -?.? |                             -?.?? |                             -?.?? |
| Cancel-in-progress     | Off      |                   ??.? |                    ?.? |                    ?.? |                    ?.? |                       -?.? |                       -?.? |                            -??.?? |                             -?.?? |
| Skip workflow          | –        |                    ?.? |                    ?.? |                    ?.? |                    ?.? |                      <-?.? |                       -?.? |                             -?.?? |                             -?.?? |
| Filtering target files | Off      |                   ??.? |                    ?.? |                   <?.? |                    ?.? |                      <-?.? |                      <-?.? |                             -?.?? |                             -?.?? |
| Custom timeout         | 360 mins |                   ??.? |                    ?.? |                    ?.? |                    ?.? |                       -?.? |                      -??.? |                            -??.?? |                             -?.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665

# Section 3: Reproduction commands (populate from reviewed steps)

# Install the artifact's Python dependencies
python -m pip install --quiet -r gh_resource_study_artifact_patched/github-workflow-resource-optimization/requirements.txt

# Execute the RQ2 notebook code programmatically and reconstruct Table 4 from the `optimizations` dict
python - <<'PY' > /workspace/repro.txt
import os
import sys
import json
import io
from pathlib import Path

root = Path("gh_resource_study_artifact_patched/github-workflow-resource-optimization").resolve()
os.chdir(root)

nb_path = Path("paper_analysis_RQ2.ipynb")
nb = json.loads(nb_path.read_text())

code_cells = []
for cell in nb.get("cells", []):
    if cell.get("cell_type") != "code":
        continue
    src = "".join(cell.get("source", []))
    if not src.strip():
        continue
    cleaned = []
    for line in src.splitlines():
        stripped = line.lstrip()
        # Skip IPython magics and shell commands
        if stripped.startswith("%") or stripped.startswith("!"):
            continue
        cleaned.append(line)
    if cleaned:
        code_cells.append("\n".join(cleaned))

full_code = "\n\n".join(code_cells)

g = {"__name__": "__main__"}
old_stdout = sys.stdout
sys.stdout = io.StringIO()
try:
    exec(full_code, g)
finally:
    sys.stdout = old_stdout

if "optimizations" not in g:
    sys.exit("Notebook code did not define `optimizations`.")

optimizations = g["optimizations"]

def fmt_rate(x: float) -> str:
    return f"{round(float(x), 1):.1f}"

def fmt_impacted(x: float) -> str:
    x = float(x)
    if 0 < x < 0.1:
        return "<0.1"
    return f"{round(x, 1):.1f}"

def fmt_time(x: float) -> str:
    x = float(x)
    if -0.1 < x < 0:
        return "<-0.1"
    return f"{round(x, 1):.1f}"

def fmt_cost(x: float) -> str:
    return f"{round(float(x), 2):.2f}"

display_names = {
    "cache": "Cache",
    "fail_fast": "Fail-fast",
    "cancel_in_progress": "Cancel-in-progress",
    "skip_workflow": "Skip workflow",
    "filtering_target_files": "Filtering target files",
    "custom_timeout": "Custom timeout",
}

defaults = {
    "cache": "Off",
    "fail_fast": "On",
    "cancel_in_progress": "Off",
    "skip_workflow": "–",
    "filtering_target_files": "Off",
    "custom_timeout": "360 mins",
}

order = [
    "cache",
    "fail_fast",
    "cancel_in_progress",
    "skip_workflow",
    "filtering_target_files",
    "custom_timeout",
]

out_lines = []
out_lines.append("**Table 4: Prevalence and impact of workflows optimizations.**")
out_lines.append("")
out_lines.append("| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |")
out_lines.append("| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |")

for key in order:
    o = optimizations[key]
    paid = o["paid"]
    free = o["free"]

    paid_adopt = fmt_rate(paid["adoption"])
    free_adopt = fmt_rate(free["adoption"])
    paid_imp = fmt_impacted(paid["impacted_runs"])
    free_imp = fmt_impacted(free["impacted_runs"])
    paid_vm = fmt_time(paid["time_impact"])
    free_vm = fmt_time(free["time_impact"])
    paid_cost = fmt_cost(paid["cost_impact"])
    free_cost = fmt_cost(free["cost_impact"])

    out_lines.append(
        f"| {display_names[key]} | {defaults[key]} | {paid_adopt} | {free_adopt} | {paid_imp} | {free_imp} | {paid_vm} | {free_vm} | {paid_cost} | {free_cost} |"
    )

print("\n".join(out_lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
