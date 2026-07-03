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
cd /workspace || exit 1
if [ -d ppt4j ]; then
  echo "ppt4j already exists, removing and re-cloning"
  rm -rf ppt4j
fi
# Clone the artifact repository
git clone https://github.com/pan2013e/ppt4j.git
cd ppt4j || exit 1
# (Optional) download dataset if not present. This may take long.
if [ -f download.sh ]; then
  # download.sh will place dataset under ~/database by default
  bash download.sh || true
fi
# Section 3: Reproduction commands (populate from reviewed steps)
# Build the project and run the replication script. The script prints D1/D2 metrics.
# The database is expected at ~/database (see framework/src/main/resources/ppt4j.properties)
mvn clean install -DskipTests >/workspace/repro_build.log 2>&1 || true
# Run the replication script and capture output
python3 /workspace/ppt4j/replicate_rq1.py > /workspace/repro.txt 2>&1 || true
# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submit_block.txt
# Print the relevant part of reproduction results (if present)
if [ -f /workspace/repro.txt ]; then
  # extract the section with PPT4J results
  sed -n '/-----------   PPT4J   ------------/,/D2/{p}' /workspace/repro.txt >> /workspace/repro_submit_block.txt || true
fi
# Also include the raw reproduction log for inspection
echo '' >> /workspace/repro_submit_block.txt
echo 'Full reproduction log available at /workspace/repro.txt' >> /workspace/repro_submit_block.txt
echo '</artisan_submit>' >> /workspace/repro_submit_block.txt
