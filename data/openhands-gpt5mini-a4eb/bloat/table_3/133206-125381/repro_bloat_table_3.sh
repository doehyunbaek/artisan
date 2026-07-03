#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
| Merged    |       30 |              35 |
| Approved  |        1 |               1 |
| Rejected  |        1 |               1 |
| Pending   |        4 |               5 |
| **Total** |   **36** |          **42** |

EOTABLE
# Section 2: Artifact download
curl -L -o /workspace/bloat-study-artifact-v1.0.zip "https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip?download=1"
mkdir -p /workspace/artifact
unzip -o /workspace/bloat-study-artifact-v1.0.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
# Install Python requirements (needed to run scripts/rq4.py)
python3 -m pip install -r /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5/requirements.txt --quiet
# Run the reproduction command to produce Table 3 output
cd /workspace/artifact/gdrosos-bloat-study-artifact-0fe2fe5
python3 scripts/rq4.py data/results/qualitative_results.json --table3 > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
