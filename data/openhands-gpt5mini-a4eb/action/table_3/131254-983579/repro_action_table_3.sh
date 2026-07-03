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

# Section 2: Artifact download
# Download the Zenodo artifact (same file used interactively above)
curl -L -o /workspace/gh_resource_study_artifact_patched.zip "https://zenodo.org/records/10529665/files/gh_resource_study_artifact_patched.zip?download=1"

# Section 3: Reproduction commands
# Extract repository and key CSVs
unzip -o /workspace/gh_resource_study_artifact_patched.zip -d /workspace/repo
# Run the reproduction Python script (assumes Python and pandas available)
python3 /workspace/compute_table3.py

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
