#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Termination status: comparison between free tier and paid tier.**

| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |
| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |
| Success         |                     78.7 |                     88.9 |                        66.4 |                        81.1 |
| Failure         |                     17.4 |                     10.0 |                        30.9 |                        18.0 |
| Skipped         |                      2.2 |                      0.6 |                         0.0 |                         0.0 |
| Canceled        |                      1.5 |                      0.3 |                         2.7 |                         0.8 |
| Startup failure |                      0.1 |                      0.1 |                         0.0 |                         0.0 |
| Action required |                    < 0.1 |                      0.1 |                         0.0 |                         0.0 |
| Stale           |                    < 0.1 |                      0.0 |                         0.0 |                         0.0 |

EOTABLE

# Section 2: Artifact download (skip if already present)
ARTIFACT_ZIP=/workspace/gh_resource_study_artifact_patched.zip
ARTIFACT_TAR=/workspace/github_study_container_patched.tar
if [ ! -f "$ARTIFACT_ZIP" ]; then
  echo "Downloading artifact..."
  curl -L -f --retry 3 -o "$ARTIFACT_ZIP" 'https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content'
fi

# Extract the included docker image tar from the zip (if not already extracted)
if [ ! -f "$ARTIFACT_TAR" ]; then
  echo "Extracting docker image tar from archive..."
  unzip -p "$ARTIFACT_ZIP" 'github-workflow-resource-optimization/github_study_container_patched.tar' > "$ARTIFACT_TAR"
fi

# Section 3: Reproduction commands
# Load the docker image (harmless if already loaded)
docker image load -i "$ARTIFACT_TAR" || true

# Ensure no stale container with same name
docker rm -f github-study 2>/dev/null || true

# Run the container detached with an infinite sleep (as required)
docker run -d --init --entrypoint bash --name github-study islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'

# Execute the notebook that contains the RQ3 analysis (Table 3) inside the container
# We allow a long timeout for notebook execution
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && jupyter nbconvert --to notebook --execute paper_analysis_RQ3.ipynb --ExecutePreprocessor.timeout=3600 --output executed_RQ3.ipynb' || true

# Convert executed notebook to markdown for easier extraction
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && jupyter nbconvert --to markdown executed_RQ3.ipynb --output repro_RQ3.md' || true

# Copy the generated markdown out of the container
docker cp github-study:/workdir/repro_RQ3.md /workspace/repro_RQ3.md 2>/dev/null || true

# Attempt to extract the Table 3 block; fall back to grepping for "Table 3" if needed
if [ -f /workspace/repro_RQ3.md ]; then
  awk 'BEGIN{found=0} /Table 3:/{found=1} found{print} /^$/{if(found) exit}' /workspace/repro_RQ3.md > /workspace/repro.txt || true
fi

# If extraction failed, try to grep for the table lines more loosely from the executed notebook markdown
if [ ! -s /workspace/repro.txt ] && [ -f /workspace/repro_RQ3.md ]; then
  grep -n -A6 -B2 -i 'Termination status' /workspace/repro_RQ3.md > /workspace/repro.txt || true
fi

# As a last fallback, include a short note indicating the extraction did not find the table
if [ ! -s /workspace/repro.txt ]; then
  echo "ERROR: Table 3 extraction failed; see /workspace/repro_RQ3.md for full notebook output." > /workspace/repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'
