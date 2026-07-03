#!/usr/bin/bash
# Section 1: Expected table (keep obfuscated template for judging)
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | ?,??? | ??,??? | ?,??? | ?? |
| Data Analysis   | Partial call graph construction | ?,??? | ??,??? | ?,??? | ?? |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11095274

# Section 3: Reproduction commands
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5

# Build Docker image as per INSTALL.md
docker build -t bloat-study-artifact .

# Ensure no leftover container name from previous runs
docker rm -f bloat-study-repro >/dev/null 2>&1 || true

# Start long-running container with the prescribed mounts
docker run -d --init --name bloat-study-repro --entrypoint bash \
  -v "$(pwd)/scripts:/home/user/scripts" \
  -v "$(pwd)/data:/home/user/data" \
  -v "$(pwd)/figures:/home/user/figures" \
  bloat-study-artifact -c 'sleep infinity'

# Run the dataset_analysis script inside the container (methodologically reproduces Table 1)
docker exec bloat-study-repro /bin/bash --noprofile --norc -c \
  "cd /home/user && python scripts/descriptives/dataset_analysis.py \
    -json_pre data/project_dependencies_post_data_collection.json \
    -json_post data/project_dependencies_final.json" > /tmp/dataset_analysis_raw.txt

# Parse numeric results from the script output (no hard-coded digits)
dc_line=$(grep '^Data Collection' /tmp/dataset_analysis_raw.txt)
da_line=$(grep '^Data Analysis' /tmp/dataset_analysis_raw.txt)

trim() { echo "$1" | sed 's/^ *//;s/ *$//'; }

dc_projects=$(trim "$(echo "$dc_line" | awk -F'|' '{print $3}')")
dc_resolved=$(trim "$(echo "$dc_line" | awk -F'|' '{print $4}')")
dc_pypi=$(trim "$(echo "$dc_line" | awk -F'|' '{print $5}')")
dc_avg=$(trim "$(echo "$dc_line" | awk -F'|' '{print $6}')")

da_projects=$(trim "$(echo "$da_line" | awk -F'|' '{print $3}')")
da_resolved=$(trim "$(echo "$da_line" | awk -F'|' '{print $4}')")
da_pypi=$(trim "$(echo "$da_line" | awk -F'|' '{print $5}')")
da_avg=$(trim "$(echo "$da_line" | awk -F'|' '{print $6}')")

# Construct the final Markdown table for reproduction using the parsed values
cat > /workspace/repro.txt <<REPRO
**Table 1: The evolution of our initial dataset [Alfadel M 2020] after applying each step of our data collection and data analysis approach.**

| Step | Operation | Total GitHub projects | Resolved deps | PyPI releases | Avg. deps |
| --- | --- | --- | --- | --- | --- |
| Data Collection | Dependency resolution | ${dc_projects} | ${dc_resolved} | ${dc_pypi} | ${dc_avg} |
| Data Analysis   | Partial call graph construction | ${da_projects} | ${da_resolved} | ${da_pypi} | ${da_avg} |
REPRO

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
