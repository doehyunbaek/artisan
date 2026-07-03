#!/usr/bin/bash
# Section 1: Expected table
cp /workspace/expected.md /workspace/expected.md

# Section 2: Artifact download
echo "Artifact located at /workspace/NPETestArtifact"

# Section 3: Reproduction commands (populate from reviewed steps)
cp /workspace/NPETestArtifact/rq1_sheet1.csv /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
