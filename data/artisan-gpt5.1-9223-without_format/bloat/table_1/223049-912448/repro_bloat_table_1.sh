#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | ?,??? | ??,??? | ?,??? | ?? |
| Data Analysis   | Partial call graph construction | ?,??? | ??,??? | ?,??? | ?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11095274

# Move to artifact root
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5

# Ensure no leftover container from previous runs
docker rm -f bloat_table_1 >/dev/null 2>&1 || true

# Build Docker image (idempotent)
docker build -t bloat-study-artifact .

# Run container in the background with proper volume mounts
docker run -d --init --entrypoint bash --name bloat_table_1 \
    -v "$(pwd)/scripts:/home/user/scripts" \
    -v "$(pwd)/data:/home/user/data" \
    -v "$(pwd)/figures:/home/user/figures" \
    bloat-study-artifact -c 'sleep infinity'

# Run the dataset analysis script inside the container and capture raw output
docker exec bloat_table_1 /bin/bash --noprofile --norc -c \
  "cd /home/user && python scripts/descriptives/dataset_analysis.py \
    -json_pre data/project_dependencies_post_data_collection.json \
    -json_post data/project_dependencies_final.json" \
  > /workspace/repro_raw.txt

# Stop and remove the container
docker rm -f bloat_table_1 >/dev/null 2>&1 || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Parse /workspace/repro_raw.txt to build the final markdown table in /workspace/repro.txt
python - <<'PYINNER'
import pathlib

raw_path = pathlib.Path("/workspace/repro_raw.txt")
text = raw_path.read_text()

lines = [l for l in text.splitlines() if l.strip()]
dc_line = next(l for l in lines if l.strip().startswith("Data Collection"))
da_line = next(l for l in lines if l.strip().startswith("Data Analysis"))

def parse_line(line):
    parts = [p.strip() for p in line.split('|')]
    # Expected: [Step, Operation, Total GitHub Projects, Resolved Dependencies, PyPI Releases, Average Dependencies (Per Project)]
    projects = int(parts[2])
    resolved = int(parts[3])
    pypi = int(parts[4])
    avg = float(parts[5])
    return projects, resolved, pypi, avg

dc_p, dc_d, dc_r, dc_avg = parse_line(dc_line)
da_p, da_d, da_r, da_avg = parse_line(da_line)

def fmt_int(n: int) -> str:
    # Add thousands separators
    return f"{n:,}"

def fmt_avg(x: float) -> str:
    # Round to nearest integer to match the paper text (e.g., 21 and 17)
    return f"{round(x):d}"

table = f"""**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | {fmt_int(dc_p)} | {fmt_int(dc_d)} | {fmt_int(dc_r)} | {fmt_avg(dc_avg)} |
| Data Analysis   | Partial call graph construction | {fmt_int(da_p)} | {fmt_int(da_d)} | {fmt_int(da_r)} | {fmt_avg(da_avg)} |
"""

pathlib.Path("/workspace/repro.txt").write_text(table)
PYINNER

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
