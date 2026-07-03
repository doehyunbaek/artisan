#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=3) | 4.5% (<0.1%) of all runs<br>17.2% (1.0%) of scheduled runs |  3.2% (<0.1%) of all runs time<br>21.3% (4.9%) of scheduled runs time |                         -125.72 (-1.55) |
| Deactivate scheduled workflows during repository inactivity       |  4.5% (0.6%) of all runs<br>17.1% (1.4%) of scheduled runs | <0.1% (<0.1%) of all runs time<br>0.1% (0.1%) of scheduled runs time |                          -99.78 (-3.81) |
| Run previously failed jobs first                                  |     1.0% (0.8%) of all runs<br>29.5% (7.7%) of failed runs |    1.1% (<0.1%) of all runs time<br>31.6% (45.3%) of failed runs time |                          -17.89 (-0.77) |
| Project-specific timeouts                                         |                                   0.5% (<0.1%) of all runs |                                          3.5% (2.2%) of all runs time |                        -173.71 (-47.49) |

* measurement for paid tier (measurement for free tier)

EOTABLE

# Section 2: Artifact download
# Download record metadata and the artifact zip from Zenodo
curl -s 'https://zenodo.org/api/records/10529665' -o /workspace/zenodo_record.json
# download the file content URL for the main artifact (follows redirects)
curl -L -o /workspace/gh_resource_study_artifact_patched.zip "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content"

# Section 3: Reproduction commands
# Pull the published Docker image, start a detached container, execute the RQ3 notebook, and extract Table 5
docker pull islemdockerdev/github-workflow-resource-study:v1.1
# run container detached (if already exists, start it)
docker run -d --init --entrypoint bash --name github-study islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity' || docker start github-study
sleep 2
# Execute the paper_analysis_RQ3 notebook inside the container (might take ~17 minutes and need ~9GB RAM)
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && jupyter nbconvert --to notebook --execute paper_analysis_RQ3.ipynb --ExecutePreprocessor.timeout=3600 --output paper_analysis_RQ3_executed.ipynb"

# Extract the markdown cell(s) containing 'Table 5' from the executed notebook and write to host /workspace/repro.txt
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && python3 - <<'PY'
import nbformat,sys
nb=nbformat.read('paper_analysis_RQ3_executed.ipynb', as_version=4)
found=False
for cell in nb.cells:
    if cell.get('cell_type')=='markdown' and 'Table 5' in cell.get('source',''):
        sys.stdout.write(cell['source'] + '\\n')
        found=True
# If no explicit 'Table 5' markdown cell found, try to dump any markdown cell that looks like a table (contains '| Optimization heuristic')
if not found:
    for cell in nb.cells:
        if cell.get('cell_type')=='markdown' and 'Optimization heuristic' in cell.get('source',''):
            sys.stdout.write(cell['source'] + '\\n')
            found=True
if not found:
    sys.stderr.write('Table 5 not found in executed notebook\\n')
PY" > /workspace/repro.txt 2>/workspace/repro_err.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission.txt
if [ -s /workspace/repro.txt ]; then
  cat /workspace/repro.txt >> /workspace/repro_submission.txt
else
  echo "ERROR: reproduction output not found. See /workspace/repro_err.txt for details." >> /workspace/repro_submission.txt
fi
echo '</artisan_submit>' >> /workspace/repro_submission.txt

# Print the submission block to stdout for convenience
cat /workspace/repro_submission.txt

