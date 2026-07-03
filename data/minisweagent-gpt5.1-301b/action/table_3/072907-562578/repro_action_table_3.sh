#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Termination status: comparison between free tier and paid tier.**

| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |
| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |
| Success         |                     78.7 |                     88.9 |                        66.4 |                        81.1 |
| Failure         |                     17.4 |                     10.0 |                        30.9 |                        18.0 |
| Skipped         |                      2.2 |                      0.6 |                         0.0 |                         0.0 |
| Canceled        |                      1.5 |                      0.3 |                         2.7 |                         0.8 |
| Startup failure |                      0.1 |                      0.1 |                         0.0 |                         0.0 |
| Action required |                    < 0.1 |                      0.1 |                         0.0 |                         0.0 |
| Stale           |                    < 0.1 |                      0.0 |                         0.0 |                         0.0 |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f gh_resource_study_artifact_patched.zip ]; then
  curl -L -o gh_resource_study_artifact_patched.zip "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content"
fi
if [ ! -d github-workflow-resource-optimization ]; then
  unzip -o gh_resource_study_artifact_patched.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Pull Docker image (preferred per README)
docker pull islemdockerdev/github-workflow-resource-study:v1.1

# Start a fresh long-lived container for reproduction
if docker ps -a --format '{{.Names}}' | grep -q '^github-study-table3$'; then
  docker rm -f github-study-table3
fi
docker run -d --init --name github-study-table3 --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# Create a Python script inside the container to reproduce Table 3
docker exec github-study-table3 /bin/bash --noprofile --norc -c 'cd /workdir && cat > repro_table_3.py << "PY"
import os
import sys
import pandas as pd

# Ensure we can import the local analysis package
THIS_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(THIS_DIR, "src")
if SRC_DIR not in sys.path:
    sys.path.insert(0, SRC_DIR)

from runs_analysis import resource_usage


class CSVDataSet:
    def __init__(self, root: str) -> None:
        self.root = root

    def get_all_runs(self) -> pd.DataFrame:
        return pd.read_csv(os.path.join(self.root, "all_runs.csv"))

    def get_all_jobs(self) -> pd.DataFrame:
        return pd.read_csv(os.path.join(self.root, "all_jobs.csv"))

    def get_all_steps(self) -> pd.DataFrame:
        return pd.read_csv(os.path.join(self.root, "all_steps.csv"))


def fmt_prop(df: pd.DataFrame, conclusion: str) -> str:
    row = df[df["conclusion"] == conclusion]
    if row.empty:
        return "0.0"
    val = float(row["prop"].iloc[0])
    rounded = round(val, 1)
    # Match paper formatting: show "< 0.1" when non-zero but rounds to 0.0
    if rounded == 0.0 and val > 0.0:
        return "< 0.1"
    return f"{rounded:.1f}"


def main() -> None:
    data_set = CSVDataSet(".")
    # Same tier split as the RQ1 notebook
    repos_list_1, repos_list_2 = resource_usage.get_tiers(data_set)

    all_runs = data_set.get_all_runs()
    all_jobs = data_set.get_all_jobs()

    # Paid tier (list_1) and free tier (list_2), mirroring the notebook logic
    all_runs_1 = all_runs[all_runs["repo_id"].isin(repos_list_1)]
    all_jobs_1 = all_jobs[(all_jobs["run_id"].isin(all_runs_1["id"])) & (all_jobs["id"] != 3253494537)]

    all_runs_2 = all_runs[all_runs["repo_id"].isin(repos_list_2)]
    all_jobs_2 = all_jobs[(all_jobs["run_id"].isin(all_runs_2["id"])) & (all_jobs["id"] != 3253494537)]

    conclusion_1 = all_runs_1.groupby("conclusion").agg(id=("id", "count")).reset_index()
    conclusion_2 = all_runs_2.groupby("conclusion").agg(id=("id", "count")).reset_index()
    conclusion_1["prop"] = conclusion_1["id"] * 100.0 / conclusion_1["id"].sum()
    conclusion_2["prop"] = conclusion_2["id"] * 100.0 / conclusion_2["id"].sum()

    runs_with_time_1 = all_runs_1.merge(all_jobs_1[["run_id", "up_time"]], left_on="id", right_on="run_id")
    runs_with_time_2 = all_runs_2.merge(all_jobs_2[["run_id", "up_time"]], left_on="id", right_on="run_id")

    time_per_conclusion_1 = runs_with_time_1.groupby("conclusion").agg(up_time=("up_time", "sum")).reset_index()
    time_per_conclusion_1["prop"] = time_per_conclusion_1["up_time"] * 100.0 / time_per_conclusion_1["up_time"].sum()

    time_per_conclusion_2 = runs_with_time_2.groupby("conclusion").agg(up_time=("up_time", "sum")).reset_index()
    time_per_conclusion_2["prop"] = time_per_conclusion_2["up_time"] * 100.0 / time_per_conclusion_2["up_time"].sum()

    # Map internal conclusion labels to the paper labels
    label_map = {
        "success": "Success",
        "failure": "Failure",
        "skipped": "Skipped",
        "cancelled": "Canceled",
        "startup_failure": "Startup failure",
        "action_required": "Action required",
        "stale": "Stale",
    }
    order = [
        "success",
        "failure",
        "skipped",
        "cancelled",
        "startup_failure",
        "action_required",
        "stale",
    ]

    print("**Table 3: Termination status: comparison between free tier and paid tier.**")
    print()
    print("| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |")
    print("| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |")

    for key in order:
        status_label = label_map.get(key, key)
        paid_runs = fmt_prop(conclusion_1, key)
        free_runs = fmt_prop(conclusion_2, key)
        paid_vm = fmt_prop(time_per_conclusion_1, key)
        free_vm = fmt_prop(time_per_conclusion_2, key)
        print(f"| {status_label:<14} | {paid_runs:>23} | {free_runs:>23} | {paid_vm:>25} | {free_vm:>25} |")


if __name__ == "__main__":
    main()
PY'

# Run the reproduction script inside the container and capture output
docker exec github-study-table3 /bin/bash --noprofile --norc -c "cd /workdir && python repro_table_3.py" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
