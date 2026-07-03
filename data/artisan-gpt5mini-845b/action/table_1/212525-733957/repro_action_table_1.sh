#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summary of resource usage by triggering event.**

| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Pull Request |             ??.? |             ??.? |          ??.? |          ??.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Push         |             ??.? |             ??.? |          ??.? |          ??.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Schedule     |             ??.? |             ??.? |          ??.? |          ??.? |                  ??.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| PR target    |              ?.? |              ?.? |           ?.? |           ?.? |                  ?.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Dispatch     |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Workflow run |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                     <?.?? |
| Release      |              ?.? |              ?.? |           ?.? |           ?.? |                 ??.? (??.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |
| Others       |              ?.? |              ?.? |           ?.? |           ?.? |                   ?.? (?.?) |                   ?.? (?.?) |                      ?.?? |                      ?.?? |

* mean (inter-quartile range)

EOTABLE
# Section 2: Artifact download (redirect verbose output to logs to avoid huge stdout)
artisan get https://zenodo.org/records/10529665 > /tmp/artifact_get.log 2>&1 || true

# Section 3: Reproduction commands (robust and quiet)
# Ensure the docker image is present (pull) and suppress output
docker pull islemdockerdev/github-workflow-resource-study:v1.1 > /tmp/docker_pull.log 2>&1 || true
# Remove any existing container with the name, ignoring errors
docker rm -f github-study > /tmp/docker_rm.log 2>&1 || true
# Run the container detached with a sleep loop
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity' > /tmp/docker_run.log 2>&1 || true
# Start it if present (no-op if already running); suppress output
docker start github-study > /tmp/docker_start.log 2>&1 || true

# Execute the RQ1 notebook inside the container using the included venv; log nbconvert output
docker exec github-study /bin/bash --noprofile --norc -c "source /workdir/.venv2/bin/activate && python -m nbconvert --to markdown --execute /workdir/paper_analysis_RQ1.ipynb --output paper_analysis_RQ1.md --output-dir /workdir/tables --ExecutePreprocessor.timeout=0" > /tmp/nbconvert.log 2>&1 || true

# Copy the generated markdown to the expected repro file location
docker cp github-study:/workdir/tables/paper_analysis_RQ1.md /workspace/repro.txt > /tmp/docker_cp.log 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
