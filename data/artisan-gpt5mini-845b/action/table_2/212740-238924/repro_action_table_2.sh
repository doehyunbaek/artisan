#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Summary of resource consumption by CI/CD tasks.**

| Task        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ----------- | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Test        |             ??.? |             ??.? |          ??.? |          ??.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Build       |             ??.? |             ??.? |          ??.? |          ??.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Release     |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Analyze     |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Lint        |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Linux       |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Update      |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Integration |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Deploy      |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Sync        |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |

* mean (inter-quartile range)

EOTABLE

# Section 2: Artifact download (required by workflow)
artisan get https://zenodo.org/records/10529665 || true

# Section 3: Reproduction commands
# Ensure any prior container is removed, then start a fresh one
docker rm -f github-study >/dev/null 2>&1 || true
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# Execute the RQ1 notebook using the environment's jupyter-nbconvert
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && /workdir/.venv2/bin/jupyter-nbconvert --to notebook --execute paper_analysis_RQ1.ipynb --ExecutePreprocessor.timeout=3600 --output executed_RQ1.ipynb'

# Convert the executed notebook to markdown
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && /workdir/.venv2/bin/jupyter-nbconvert --to markdown executed_RQ1.ipynb --output executed_RQ1.md'

# Extract the exact markdown table block for "Resource usage by task (Table 2 in PDF)" 
# from the markdown (from the '| Task' header down to the '* mean' footnote)
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && sed -n "/^| Task/,/^\* mean/p" executed_RQ1.md > repro_table2.md || true'

# Copy the extracted table to the host as repro.txt
docker cp github-study:/workdir/repro_table2.md /workspace/repro.txt || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'
