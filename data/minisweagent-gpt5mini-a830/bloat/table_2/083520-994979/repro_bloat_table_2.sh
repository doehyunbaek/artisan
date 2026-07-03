#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics on the resolved and unresolved external calls during our stitching process.**

|  | External Calls | Aggregate count | Proportion of total | Average (per project) | Median (per project) |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |
|  | Resolved | 7,799,929 | 96.8% | 5,991 | 144.5 |
|  | Unresolved | 260,249 | 3.2% | 200 | 11.5 |

EOTABLE

# Section 2: Artifact download
curl -L -o /workspace/bloat-study-artifact-v1.0.zip 'https://zenodo.org/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip'
unzip -o /workspace/bloat-study-artifact-v1.0.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
# Install required Python dependency
python3 -m pip install --user pandas

# Determine artifact top-level directory (artifact was unpacked into a single subdirectory)
ART_DIR=$(ls -1 /workspace/artifact | head -n 1)

# Run the evaluation script to reproduce Table 2, saving output to /workspace/repro.txt
python3 /workspace/artifact/"$ART_DIR"/scripts/descriptives/evaluation.py -csv /workspace/artifact/"$ART_DIR"/data/results/rq1a.csv > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
