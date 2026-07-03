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
# Section 3: Reproduction commands
# Load Docker image and run container
docker load -i gh_resource_study_artifact_patched/github-workflow-resource-optimization/github_study_container_patched.tar
CONTAINER_ID=$(docker run -d --init --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity')
sleep 5
# Install jupyter and nbconvert
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /workdir && pip install jupyter nbconvert 2>/dev/null"
# Execute the notebook
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "cd /workdir && /workdir/.venv2/bin/jupyter nbconvert --to notebook --execute paper_analysis_RQ2.ipynb --output /tmp/output_RQ2.ipynb 2>&1"
# Extract the table and format it
docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "python3 << 'EOF'
import nbformat
import re
with open('/tmp/output_RQ2.ipynb', 'r') as f:
    nb = nbformat.read(f, as_version=4)
full_text = ''
for cell in nb.cells:
    if cell.cell_type == 'code':
        for output in cell.get('outputs', []):
            if output.output_type == 'stream':
                full_text += output.text
# Extract the table part
lines = full_text.split('\\n')
table_start = None
for i, line in enumerate(lines):
    if 'Adoption rate %' in line and 'Impacted runs %' in line:
        table_start = i
        break
if table_start is None:
    print('Table not found')
    exit(1)
# The table has 6 rows of data
data_rows = []
for line in lines[table_start+4:table_start+10]:
    if line.strip():
        parts = re.split(r'\\s{2,}', line.strip())
        if len(parts) == 9:
            data_rows.append(parts)
# Map the optimization names and defaults
name_map = {
    'cache': 'Cache',
    'fail_fast': 'Fail-fast',
    'cancel_in_progress': 'Cancel-in-progress',
    'skip_workflow': 'Skip workflow',
    'filtering_target_files': 'Filtering target files',
    'custom_timeout': 'Custom timeout'
}
default_map = {
    'Cache': 'Off',
    'Fail-fast': 'On',
    'Cancel-in-progress': 'Off',
    'Skip workflow': '–',
    'Filtering target files': 'Off',
    'Custom timeout': '360 mins'
}
# Print the table in markdown
print('**Table 4: Prevalence and impact of workflows optimizations.**')
print()
print('| Optimization | Default | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |')
print('| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |')
for row in data_rows:
    opt_key = row[0]
    opt_name = name_map.get(opt_key, opt_key)
    default = default_map[opt_name]
    print(f'| {opt_name} | {default} | {row[1]} | {row[2]} | {row[3]} | {row[4]} | {row[5]} | {row[6]} | {row[7]} | {row[8]} |')
EOF" > /workspace/repro.txt
# Section 4: Formatting and submission
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
