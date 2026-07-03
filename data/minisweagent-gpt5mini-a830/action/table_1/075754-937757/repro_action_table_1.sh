#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summary of resource usage by triggering event.**

| Event        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |
| ------------ | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |
| Pull Request |             50.7 |             35.5 |          38.6 |          25.3 |                 31.1 (20.1) |                   3.6 (3.6) |                      0.36 |                      0.04 |
| Push         |             30.9 |             47.8 |          26.4 |          28.6 |                 28.4 (19.5) |                   4.3 (4.2) |                      0.33 |                      0.05 |
| Schedule     |             15.5 |             14.5 |          26.2 |          40.3 |                  13.8 (1.3) |                   0.9 (0.2) |                      0.17 |                      0.01 |
| PR target    |              1.2 |              0.6 |           4.2 |           1.4 |                  8.5 (11.9) |                   1.2 (1.3) |                      0.08 |                      0.01 |
| Dispatch     |              0.7 |              0.5 |           0.2 |           0.3 |                 71.9 (24.9) |                   5.1 (4.4) |                      0.87 |                      0.06 |
| Workflow run |              0.7 |              0.0 |           0.7 |           0.4 |                 23.2 (13.0) |                   0.1 (0.1) |                      0.19 |                     <0.01 |
| Release      |              0.2 |              0.5 |           0.1 |           0.3 |                 40.0 (15.0) |                   4.2 (5.9) |                      0.32 |                      0.03 |
| Others       |              0.1 |              0.6 |           3.6 |           3.4 |                   4.5 (1.4) |                   0.7 (0.6) |                      0.05 |                      0.01 |

* mean (inter-quartile range)

EOTABLE

# Section 2: Artifact download (skip if already present)
if [ ! -f /workspace/gh_resource_study_artifact_patched.zip ]; then
  curl -L -o /workspace/gh_resource_study_artifact_patched.zip 'https://zenodo.org/records/10529665/files/gh_resource_study_artifact_patched.zip?download=1' || true
fi
mkdir -p /workspace/artifact
if [ -f /workspace/gh_resource_study_artifact_patched.zip ] && [ ! -d /workspace/artifact/github-workflow-resource-optimization ]; then
  unzip -qq /workspace/gh_resource_study_artifact_patched.zip -d /workspace/artifact || true
fi

# Section 3: Reproduction commands
# Pull the Docker image (best-effort), remove any existing container, and start a fresh one
docker pull islemdockerdev/github-workflow-resource-study:v1.1 || true
docker rm -f github-study 2>/dev/null || true
docker run -d --init --entrypoint bash --name github-study islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity' || true

# Ensure Jupyter/nbconvert and kernel support exist inside the container
docker exec github-study /bin/bash --noprofile --norc -c "pip install --upgrade pip && pip install jupyter nbconvert ipykernel" || true

# Install the project package so notebooks can import project modules
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && pip install -e ." || true

# Execute the RQ1 notebook (reproduces Tables 1-3) with no timeout
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && jupyter nbconvert --to notebook --execute paper_analysis_RQ1.ipynb --output executed_paper_analysis_RQ1.ipynb --ExecutePreprocessor.timeout=0" || true

# Capture produced table outputs into host file
docker exec github-study /bin/bash --noprofile --norc -c "if [ -d /workdir/tables ]; then ls -la /workdir/tables; echo '----FILES START----'; for f in /workdir/tables/*; do if [ -f \"\$f\" ]; then echo '===== '\"\$f\"' ====='; sed -n '1,200p' \"\$f\"; echo '----'; fi; done; else echo '/workdir/tables not found'; fi" > /workspace/repro.txt || true

# Append executed notebook presence info
docker exec github-study /bin/bash --noprofile --norc -c "if [ -f /workdir/executed_paper_analysis_RQ1.ipynb ]; then echo 'executed notebook present'; ls -lh /workdir/executed_paper_analysis_RQ1.ipynb; else echo 'executed notebook not present'; fi" >> /workspace/repro.txt || true

# Section 4: Submission block output
echo '<artisan_submit>'
if [ -s /workspace/repro.txt ]; then
  cat /workspace/repro.txt
else
  echo 'No reproduction output was captured in /workspace/repro.txt'
fi
echo '</artisan_submit>'

# Finalize
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
