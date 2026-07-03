#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Test results on the dataset**

| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |
| ---------- | ------ | ---------------: | ----: | -----: | ----: |
| PPT4J      | **D1** |             100% |  100% |   100% |  100% |
|            | **D2** |            98.5% |  100% |  97.0% | 98.5% |

EOTABLE
# Section 2: Artifact download
if [ ! -d /workspace/ppt4j ]; then
  git clone https://github.com/pan2013e/ppt4j /workspace/ppt4j
else
  echo "/workspace/ppt4j already exists; skipping clone"
fi
# Section 3: Reproduction commands (populate from reviewed steps)
# Note: This script will download the dataset from Zenodo (~13GB for 'complete').
# Ensure sufficient disk space and a network connection before running.
cd /workspace/ppt4j
# Download dataset into ${HOME} (creates ${HOME}/database)
# If you already have the dataset, skip this step.
if [ ! -d "${HOME}/database" ]; then
  echo "Starting dataset download. This may take a long time..."
  bash download.sh
else
  echo "Dataset already present at ${HOME}/database; skipping download"
fi
# Build the project (requires JDK, Maven)
python -m scripts.build
# Run the replication script that computes Table 2 results
# Output will be saved to /workspace/repro.txt
python3 replicate_rq1.py > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Print the PPT4J summary block from the reproduction output
if [ -f /workspace/repro.txt ]; then
  sed -n '/-----------   PPT4J   ------------/,/\$/p' /workspace/repro.txt
else
  echo 'No reproduction output found.'
fi
echo '</artisan_submit>'
