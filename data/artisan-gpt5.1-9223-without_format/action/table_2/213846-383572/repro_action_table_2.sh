#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of resource consumption by CI/CD tasks.**

| Task        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ----------- | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Test        |             54.6 |             37.3 |          50.9 |          36.2 |                   8.1 (7.2) |                   1.5 (1.3) |                     0.10 |                     0.02 |
| Build       |             36.6 |             50.8 |          28.5 |          49.9 |                   9.7 (8.4) |                   1.5 (1.3) |                     0.12 |                     0.02 |
| Release     |              3.5 |              1.3 |           2.4 |           2.0 |                 11.0 (20.1) |                   1.0 (1.2) |                     0.13 |                     0.01 |
| Analyze     |              1.9 |              6.3 |           2.1 |           2.8 |                   6.6 (5.6) |                   3.4 (2.4) |                     0.08 |                     0.04 |
| Lint        |              1.0 |              2.5 |           4.3 |           4.9 |                   1.8 (1.7) |                   0.8 (0.4) |                     0.02 |                     0.01 |
| Linux       |              0.9 |              0.4 |           1.5 |           0.4 |                   4.5 (1.8) |                   1.4 (1.6) |                     0.05 |                     0.02 |
| Update      |              0.7 |              0.2 |           5.8 |           0.5 |                   1.0 (1.0) |                   0.7 (1.2) |                     0.01 |                     0.01 |
| Integration |              0.4 |              0.8 |           1.2 |           0.5 |                   2.6 (2.1) |                   2.4 (1.4) |                     0.03 |                     0.03 |
| Deploy      |              0.3 |              0.4 |           1.7 |           2.1 |                   1.3 (1.5) |                   0.3 (0.2) |                     0.02 |                     0.00 |
| Sync        |              0.0 |              0.1 |           1.7 |           0.7 |                   0.2 (0.0) |                   0.2 (0.1) |                     0.00 |                     0.00 |

* mean (inter-quartile range)

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
python - <<'PY'
import json
import re
from pathlib import Path

# Path to the executed RQ1 notebook within the downloaded artifact
nb_path = Path("/workspace/gh_resource_study_artifact_patched/github-workflow-resource-optimization/paper_analysis_RQ1.ipynb")

with nb_path.open() as f:
    nb = json.load(f)

lines = []
for cell in nb.get("cells", []):
    for out in cell.get("outputs", []):
        text = out.get("text")
        if not text:
            continue
        if isinstance(text, list):
            for t in text:
                lines.extend(t.splitlines())
        else:
            lines.extend(str(text).splitlines())

tasks_order = ["test", "build", "release", "analyze", "lint", "linux", "update", "integration", "deploy", "sync"]

pattern = re.compile(
    r'^\s*(\w+)\s+'              # task
    r'([0-9.]+)\s+'              # VM time % paid
    r'([0-9.]+)\s+'              # VM time % free
    r'([0-9.]+)\s+'              # runs % paid
    r'([0-9.]+)\s+'              # runs % free
    r'([0-9.]+)\s+\(iqr=([0-9.]+)\s*\)\s+'  # VM time per run paid + IQR
    r'([0-9.]+)\s+\(iqr=([0-9.]+)\s*\)\s+'  # VM time per run free + IQR
    r'([0-9.]+)\s+'              # VM cost paid
    r'([0-9.]+)\s*$'             # VM cost free
)

rows = {}
for line in lines:
    m = pattern.match(line)
    if not m:
        continue
    task = m.group(1)
    if task in tasks_order:
        rows[task] = m.groups()

if set(rows.keys()) != set(tasks_order):
    raise SystemExit(f"Did not find all task rows in notebook output. Found: {sorted(rows.keys())}")

out_path = Path("/workspace/repro.txt")
with out_path.open("w") as out:
    out.write("**Table 2: Summary of resource consumption by CI/CD tasks.**\n\n")
    out.write("| Task        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |\n")
    out.write("| ----------- | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |\n")

    for task in tasks_order:
        g = rows[task]
        (
            _task,
            vm_paid, vm_free,
            runs_paid, runs_free,
            vmt_paid, iqr_paid,
            vmt_free, iqr_free,
            cost_paid, cost_free,
        ) = g

        name = task.capitalize()
        row = (
            f"| {name:<10} | "
            f"{float(vm_paid):15.1f} | {float(vm_free):15.1f} | "
            f"{float(runs_paid):12.1f} | {float(runs_free):12.1f} | "
            f"{float(vmt_paid):25.1f} ({float(iqr_paid):.1f}) | "
            f"{float(vmt_free):25.1f} ({float(iqr_free):.1f}) | "
            f"{float(cost_paid):22.2f} | {float(cost_free):22.2f} |\n"
        )
        out.write(row)

    out.write("\n* mean (inter-quartile range)\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
