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
curl -L 'https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip' -o artifact.zip
unzip -q artifact.zip -d artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
# Build docker image as recommended in INSTALL.md (might be a no-op if already built)
# (Not executed here to keep script self-contained in environments without Docker.)
# docker build -t bloat-study-artifact .

# Instead, run the descriptive script directly on the host environment.
python scripts/descriptives/dataset_analysis.py  \
  -json_pre data/project_dependencies_post_data_collection.json \
  -json_post data/project_dependencies_final.json \
  > /workspace/repro_raw.txt

# Extract just the table lines into repro.txt
awk 'BEGIN{capture=0} /Step[[:space:]]+\|[[:space:]]+Operation/{capture=1} capture{print} END{}' /workspace/repro_raw.txt > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
