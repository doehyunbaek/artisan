#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o bloat-study-artifact-v1.0.zip https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content
unzip -o bloat-study-artifact-v1.0.zip
cd /workspace/gdrosos-bloat-study-artifact-0fe2fe5
docker build -t bloat-study-artifact .

docker run -d --init --entrypoint bash --name bloat_table_1 \
    -v "$(pwd)/scripts:/home/user/scripts" \
    -v "$(pwd)/data:/home/user/data" \
    -v "$(pwd)/figures:/home/user/figures" \
    bloat-study-artifact -c 'sleep infinity'

docker exec bloat_table_1 /bin/bash --noprofile --norc -c \
  "cd /home/user && python scripts/descriptives/dataset_analysis.py \
    -json_pre data/project_dependencies_post_data_collection.json \
    -json_post data/project_dependencies_final.json" \
  > /workspace/repro_raw.txt

docker rm -f bloat_table_1 >/dev/null 2>&1 || true

python - <<'PYINNER'
import pathlib

raw_path = pathlib.Path("/workspace/repro_raw.txt")
text = raw_path.read_text()

lines = [l for l in text.splitlines() if l.strip()]
dc_line = next(l for l in lines if l.strip().startswith("Data Collection"))
da_line = next(l for l in lines if l.strip().startswith("Data Analysis"))

def parse_line(line):
    parts = [p.strip() for p in line.split('|')]

    projects = int(parts[2])
    resolved = int(parts[3])
    pypi = int(parts[4])
    avg = float(parts[5])
    return projects, resolved, pypi, avg

dc_p, dc_d, dc_r, dc_avg = parse_line(dc_line)
da_p, da_d, da_r, da_avg = parse_line(da_line)

def fmt_int(n: int) -> str:

    return f"{n:,}"

def fmt_avg(x: float) -> str:

    return f"{round(x):d}"

table = f"""**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | {fmt_int(dc_p)} | {fmt_int(dc_d)} | {fmt_int(dc_r)} | {fmt_avg(dc_avg)} |
| Data Analysis   | Partial call graph construction | {fmt_int(da_p)} | {fmt_int(da_d)} | {fmt_int(da_r)} | {fmt_avg(da_avg)} |
"""

pathlib.Path("/workspace/repro.txt").write_text(table)
PYINNER

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
