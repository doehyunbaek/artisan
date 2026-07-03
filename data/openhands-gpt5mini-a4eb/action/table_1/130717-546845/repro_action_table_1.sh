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

# Section 2: Artifact download
# Download the artifact ZIP from Zenodo (ICSE'24 artifact)
curl -sL 'https://zenodo.org/records/10529665/files/gh_resource_study_artifact_patched.zip' -o /workspace/gh_artifact.zip

# Section 3: Reproduction commands
# Extract the repository files we need (this is quicker than extracting everything)
unzip -o /workspace/gh_artifact.zip 'github-workflow-resource-optimization/*' -d /workspace/

# Run the reproduction script (the repository includes the analysis code and CSV dataset)
cd /workspace/github-workflow-resource-optimization
# Use system python; the provided script adds src/ to PYTHONPATH
/usr/bin/env python3 repro_table1.py

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Show the reproduced table
cat /workspace/repro.txt
echo '</artisan_submit>'
