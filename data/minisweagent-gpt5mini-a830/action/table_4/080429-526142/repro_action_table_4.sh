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

# Section 2: Artifact download (no-op if already present)
ARTIFACT_DIR=/workspace/artifact
mkdir -p "$ARTIFACT_DIR"
# Attempt to download the zenodo record and artifact if missing (safe to run even if files exist)
if [ ! -f "$ARTIFACT_DIR/gh_resource_study_artifact_patched.zip" ]; then
  curl -L -o "$ARTIFACT_DIR/gh_resource_study_artifact_patched.zip" "https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content" || true
fi

# Section 3: Reproduction commands (execute RQ2 notebook inside the running container,
# convert executed notebook to markdown, extract the Table 4 markdown table and copy it out)
# Notes:
# - Assumes a running container named 'github-study' as created per README instructions.
# - Notebook: /workdir/paper_analysis_RQ2.ipynb
# - Output: /workspace/repro.txt

# Execute the RQ2 notebook inside the container (timeout set to 3600s = 60min to be safe for long cells)
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && jupyter nbconvert --to notebook --execute paper_analysis_RQ2.ipynb --ExecutePreprocessor.timeout=3600 --output executed_RQ2.ipynb" || true

# Convert executed notebook to markdown inside the container
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && jupyter nbconvert --to markdown executed_RQ2.ipynb --output executed_RQ2.md" || true

# Extract the Table 4 markdown block from the generated markdown.
# Heuristic: find the table header line containing '| Optimization' and print until the next blank line.
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && awk 'BEGIN{p=0} /^\|[[:space:]]*Optimization/ {p=1} p{print} /^$/{if(p){exit}}' executed_RQ2.md > /workdir/repro_table4.md || true" || true

# Copy the extracted table out to the host workspace as repro.txt (if present)
docker cp github-study:/workdir/repro_table4.md /workspace/repro.txt || true

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submit_block.txt || true
if [ -s /workspace/repro.txt ]; then
  cat /workspace/repro.txt >> /workspace/repro_submit_block.txt
else
  echo "Reproduction output not found or extraction failed. Check executed_RQ2.ipynb and executed_RQ2.md inside the container (/workdir)." >> /workspace/repro_submit_block.txt
fi
echo '</artisan_submit>' >> /workspace/repro_submit_block.txt || true

