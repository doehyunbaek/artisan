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
cd /workspace && curl -L "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1" -o artifact.zip
unzip -o artifact.zip -d artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
python scripts/descriptives/dataset_analysis.py \
  -json_pre data/project_dependencies_post_data_collection.json \
  -json_post data/project_dependencies_final.json \
  > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Convert the output to match the table format (commas for thousands, integer rounding)
python3 <<'EOF'
import re
with open('/workspace/repro.txt', 'r') as f:
    lines = f.readlines()
# The table lines are the last three lines after empty line
for line in lines:
    if line.startswith('Data Collection') or line.startswith('Data Analysis'):
        parts = line.split('|')
        # Remove whitespace
        parts = [p.strip() for p in parts]
        # Format numbers with commas for thousands
        # Data Collection: 1644 -> 1,644, 34864 -> 34,864, 5617 -> 5,617, 21.21 -> 21
        # Data Analysis: 1302 -> 1,302, 21785 -> 21,785, 3232 -> 3,232, 16.73 -> 17
        if parts[0] == 'Data Collection':
            total_proj = int(parts[2])
            resolved_deps = int(parts[3])
            pypi_releases = int(parts[4])
            avg_deps = int(round(float(parts[5])))
            # Format with commas
            total_proj_fmt = f"{total_proj:,}"
            resolved_deps_fmt = f"{resolved_deps:,}"
            pypi_releases_fmt = f"{pypi_releases:,}"
            print(f"| Data Collection | Dependency resolution | {total_proj_fmt} | {resolved_deps_fmt} | {pypi_releases_fmt} | {avg_deps} |")
        elif parts[0] == 'Data Analysis':
            total_proj = int(parts[2])
            resolved_deps = int(parts[3])
            pypi_releases = int(parts[4])
            avg_deps = int(round(float(parts[5])))
            total_proj_fmt = f"{total_proj:,}"
            resolved_deps_fmt = f"{resolved_deps:,}"
            pypi_releases_fmt = f"{pypi_releases:,}"
            print(f"| Data Analysis   | Partial call graph construction | {total_proj_fmt} | {resolved_deps_fmt} | {pypi_releases_fmt} | {avg_deps} |")
EOF
echo '</artisan_submit>'