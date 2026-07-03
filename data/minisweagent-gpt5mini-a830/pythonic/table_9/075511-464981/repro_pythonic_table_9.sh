#!/usr/bin/bash
set -e
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 2.29 |     0.83 |     0.31 |    2.65 |    0.02 |
| Compl.      | 0.88 |    -0.13 |     0.18 |   -0.73 |    0.47 |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 1.49 |     0.40 |     0.22 |    1.84 |    0.07 |
| Compl.      | 0.77 |    -0.26 |     0.11 |   -2.27 |    0.05 |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 1.79 |     0.58 |     0.25 |    2.31 |    0.02 |
EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/artifact
curl -L -o /workspace/artifact/ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/record/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1" || true
unzip -o /workspace/artifact/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/artifact

# Section 3: Reproduction commands
# Pull Docker image
docker pull mdipenta/rexp:latest

# Ensure no stale container
docker rm -f icse_rexp >/dev/null 2>&1 || true

# Run container detached with artifact mounted at /data
docker run -d --init --entrypoint bash -v /workspace/artifact/ICSE2024-funcConstructs-Artifacts:/data --name icse_rexp mdipenta/rexp:latest -c 'sleep infinity'

# Execute the statistical R script inside the container (this will produce results/* files)
docker exec icse_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Copy produced results to a workspace results directory for easy access
rm -rf /workspace/results || true
cp -r /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results /workspace/results || true

# Aggregate the Table-9 CSV files into /workspace/repro.txt (include small headers)
echo "=== Table 9: Lambda (Table-9-rq2-lambda.csv) ===" > /workspace/repro.txt
if [ -f /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-9-rq2-lambda.csv ]; then
  sed -n '1,200p' /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-9-rq2-lambda.csv >> /workspace/repro.txt
else
  echo "MISSING: Table-9-rq2-lambda.csv" >> /workspace/repro.txt
fi

echo "" >> /workspace/repro.txt
echo "=== Table 9: Comprehension (Table-9-rq2-comp.csv) ===" >> /workspace/repro.txt
if [ -f /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-9-rq2-comp.csv ]; then
  sed -n '1,200p' /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-9-rq2-comp.csv >> /workspace/repro.txt
else
  echo "MISSING: Table-9-rq2-comp.csv" >> /workspace/repro.txt
fi

echo "" >> /workspace/repro.txt
echo "=== Table 9: MRF (Table-9-rq2-mrf.csv) ===" >> /workspace/repro.txt
if [ -f /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-9-rq2-mrf.csv ]; then
  sed -n '1,200p' /workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-9-rq2-mrf.csv >> /workspace/repro.txt
else
  echo "MISSING: Table-9-rq2-mrf.csv" >> /workspace/repro.txt
fi

# Optional: stop and remove the container
docker rm -f icse_rexp >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission_block.txt
cat /workspace/repro.txt >> /workspace/repro_submission_block.txt
echo '</artisan_submit>' >> /workspace/repro_submission_block.txt

# Print a short summary to stdout
echo "Reproduction finished. Expected table saved to /workspace/expected.md"
echo "Reproduced Table-9 CSVs (if produced) copied to /workspace/results/"
echo "Aggregated reproduction output at /workspace/repro.txt and submission block at /workspace/repro_submission_block.txt"

# Mark completion for the automated workflow
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
