#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | 1,644 | 34,864 | 5,617 | 21 |
| Data Analysis   | Partial call graph construction | 1,302 | 21,785 | 3,232 | 17 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o bloat-study-artifact-v1.0.zip "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1"
unzip -q -o bloat-study-artifact-v1.0.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/gdrosos-bloat-study-artifact-0fe2fe5
python scripts/descriptives/dataset_analysis.py \
  -json_pre data/project_dependencies_post_data_collection.json \
  -json_post data/project_dependencies_final.json > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'PY'
import pathlib

repro_path = pathlib.Path('/workspace/repro.txt')
text = repro_path.read_text().splitlines()
rows = []
for line in text:
    if line.strip().startswith('Data '):
        parts = [c.strip() for c in line.split('|')]
        if len(parts) >= 6:
            step = parts[0]
            operation = parts[1]
            total_projects = int(float(parts[2]))
            resolved_deps = int(float(parts[3]))
            pypi_releases = int(float(parts[4]))
            avg_deps = float(parts[5])
            rows.append((step, operation, total_projects, resolved_deps, pypi_releases, avg_deps))

def fmt_int(n: int) -> str:
    return f"{n:,}"

print("**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**")
print()
print("| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |")
print("| --- | --- | --- | --- | --- | --- |")
for step, operation, total_projects, resolved_deps, pypi_releases, avg_deps in rows:
    avg_rounded = round(avg_deps)
    print(f"| {step} | {operation} | {fmt_int(total_projects)} | {fmt_int(resolved_deps)} | {fmt_int(pypi_releases)} | {avg_rounded} |")
PY
echo '</artisan_submit>'
