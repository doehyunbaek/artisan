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

# Always work from the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Section 2: Artifact download
# Download the Zenodo artifact ZIP if not already present
if [ ! -f gh_resource_study_artifact_patched.zip ]; then
  curl -L "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content" \
    -o gh_resource_study_artifact_patched.zip
fi

# Unzip the artifact to create the github-workflow-resource-optimization directory
if [ ! -d github-workflow-resource-optimization ]; then
  unzip -o gh_resource_study_artifact_patched.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Pull the Docker image used by the artifact authors
if ! docker image inspect islemdockerdev/github-workflow-resource-study:v1.1 >/dev/null 2>&1; then
  docker pull islemdockerdev/github-workflow-resource-study:v1.1
fi

# Ensure a fresh container named github-study
if docker ps -a --format '{{.Names}}' | grep -q '^github-study$'; then
  docker rm -f github-study
fi

# Start the container in detached mode with a long-running bash
docker run -d --init --name github-study --entrypoint bash \
  islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# Execute the RQ1 analysis notebook inside the container
docker exec github-study /bin/bash --noprofile --norc -c \
  'source .venv2/bin/activate && jupyter nbconvert --to notebook --execute paper_analysis_RQ1.ipynb --output paper_analysis_RQ1_executed.ipynb'

# Extract the textual Table 1 results into /workspace/repro.txt
docker exec github-study /bin/bash --noprofile --norc -c \
  'source .venv2/bin/activate && jupyter nbconvert --to markdown paper_analysis_RQ1_executed.ipynb --stdout' \
  | awk '/Event *Paid/ {inblock=1} inblock {print} /Others/ && inblock {exit}' > "$SCRIPT_DIR/repro.txt"

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - <<'PY'
import re
from pathlib import Path

root = Path(__file__).resolve().parent
text = (root / "repro.txt").read_text().splitlines()

rows = []
for line in text:
    stripped = line.strip()
    if not stripped or stripped.startswith("Event"):
        continue
    name = stripped.split()[0]
    nums = [float(x) for x in re.findall(r"[-+]?\d*\.\d+|\d+", stripped)]
    if len(nums) != 10:
        raise SystemExit(f"Unexpected numeric field count in line: {line!r}")
    rows.append((name, nums))

order = [
    "pull_request",
    "push",
    "schedule",
    "pull_request_target",
    "workflow_dispatch",
    "workflow_run",
    "release",
    "Others",
]

label_map = {
    "pull_request": "Pull Request",
    "push": "Push",
    "schedule": "Schedule",
    "pull_request_target": "PR target",
    "workflow_dispatch": "Dispatch",
    "workflow_run": "Workflow run",
    "release": "Release",
    "Others": "Others",
}

row_map = {name: nums for name, nums in rows}

def fmt_pct(x: float) -> str:
    return f"{x:.1f}".rstrip("0").rstrip(".") if x % 1 == 0 else f"{x:.1f}"

def fmt_time(x: float) -> str:
    return f"{x:.1f}".rstrip("0").rstrip(".") if x % 1 == 0 else f"{x:.1f}"

def fmt_cost(x: float, is_free: bool) -> str:
    if is_free and x == 0.0:
        return "<0.01"
    return f"{x:.2f}".rstrip("0").rstrip(".") if abs(x - round(x)) < 1e-9 else f"{x:.2f}"

print("**Table 1: Summary of resource usage by triggering event.**\n")
print("| Event | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |")
print("| ------ | ----------------: | ----------------: | -------------: | -------------: | ---------------------------: | ---------------------------: | -------------------------: | -------------------------: |")

for key in order:
    nums = row_map[key]
    label = label_map[key]
    vm_paid, vm_free, runs_paid, runs_free, t_paid, iqr_paid, t_free, iqr_free, cost_paid, cost_free = nums
    vm_time_paid = fmt_pct(vm_paid)
    vm_time_free = fmt_pct(vm_free)
    runs_paid_s = fmt_pct(runs_paid)
    runs_free_s = fmt_pct(runs_free)
    time_paid = fmt_time(t_paid)
    time_free = fmt_time(t_free)
    iqr_paid_s = fmt_time(iqr_paid)
    iqr_free_s = fmt_time(iqr_free)
    cost_paid_s = fmt_cost(cost_paid, is_free=False)
    cost_free_s = fmt_cost(cost_free, is_free=True)

    paid_time_col = f"{time_paid} ({iqr_paid_s})"
    free_time_col = f"{time_free} ({iqr_free_s})"

    print(f"| {label} | {vm_time_paid} | {vm_time_free} | {runs_paid_s} | {runs_free_s} | {paid_time_col} | {free_time_col} | {cost_paid_s} | {cost_free_s} |")

print("\n* mean (inter-quartile range)")
PY
echo '</artisan_submit>'
