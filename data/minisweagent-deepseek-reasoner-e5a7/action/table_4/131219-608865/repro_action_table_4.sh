#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Prevalence and impact of workflows optimizations.**

| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |
| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |
| Cache                  | Off      |                   32.9 |                   17.8 |                  100.0 |                  100.0 |                       -3.0 |                       -6.0 |                            -19.24 |                             -0.60 |
| Fail-fast              | On       |                   75.9 |                   84.5 |                    3.1 |                    4.7 |                       -1.5 |                       -2.0 |                             -2.13 |                             -4.22 |
| Cancel-in-progress     | Off      |                   10.1 |                    1.9 |                    9.2 |                    1.7 |                       -4.1 |                       -1.6 |                            -62.63 |                             -0.52 |
| Skip workflow          | –        |                    9.5 |                    4.6 |                    0.1 |                    0.3 |                      <-0.1 |                       -0.4 |                             -2.52 |                             -0.75 |
| Filtering target files | Off      |                   21.1 |                    8.7 |                   <0.1 |                    1.8 |                      <-0.1 |                      <-0.1 |                             -2.27 |                             -0.06 |
| Custom timeout         | 360 mins |                   14.0 |                    2.6 |                    3.1 |                    4.7 |                       -8.2 |                      -12.9 |                            -58.61 |                             -1.59 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact..."
curl -s -L "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content" -o /workspace/gh_resource_study_artifact_patched.zip
echo "Unzipping artifact..."
unzip -q -o /workspace/gh_resource_study_artifact_patched.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Loading Docker image..."
docker image load -i /workspace/artifact/github-workflow-resource-optimization/github_study_container_patched.tar
echo "Starting container..."
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
echo "Executing notebook to reproduce Table 4..."
docker exec github-study /bin/bash -c "cd /workdir && source /workdir/.venv2/bin/activate && jupyter nbconvert --to notebook --execute paper_analysis_RQ2.ipynb --output repro_table4.ipynb"
docker exec github-study /bin/bash -c "cd /workdir && source /workdir/.venv2/bin/activate && jupyter nbconvert --to markdown repro_table4.ipynb --output repro_table4.md"
echo "Extracting reproduced table..."
docker exec github-study sed -n '770,800p' /workdir/repro_table4.md > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
echo "Reproduced table:"
cat /workspace/repro.txt
echo '</artisan_submit>'
