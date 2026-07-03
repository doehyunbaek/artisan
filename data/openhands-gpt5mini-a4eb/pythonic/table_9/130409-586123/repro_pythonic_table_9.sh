#!/usr/bin/bash
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
# Download the artifact zip from Zenodo and extract it
mkdir -p /workspace/artifact_dir
curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip" -o /workspace/artifact.zip
unzip -q /workspace/artifact.zip -d /workspace/artifact_dir

# Section 3: Reproduction commands
# Pull the Docker image, run it detached, and execute the R script inside it
docker pull mdipenta/rexp:latest
# Start container (detached) mounting the artifact directory
docker run -d --init --entrypoint bash -v /workspace/artifact_dir/ICSE2024-funcConstructs-Artifacts:/data --name rexp_container_local mdipenta/rexp:latest -c 'sleep infinity'
# Execute the R script inside the container; save stdout/stderr
docker exec rexp_container_local /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r > /data/run_output.txt 2>&1"
# Copy the resulting CSVs to the workspace root for submission
cp /workspace/artifact_dir/ICSE2024-funcConstructs-Artifacts/Table-9-rq2-lambda.csv /workspace/ || true
cp /workspace/artifact_dir/ICSE2024-funcConstructs-Artifacts/Table-9-rq2-comp.csv /workspace/ || true
cp /workspace/artifact_dir/ICSE2024-funcConstructs-Artifacts/Table-9-rq2-mrf.csv /workspace/ || true

# Section 4: Formatting and submission block
# Produce a single reproduction output file combining the three CSVs
echo '<artisan_submit>' > /workspace/repro.txt
echo '--- EXPECTED TABLE ---' >> /workspace/repro.txt
cat /workspace/expected.md >> /workspace/repro.txt
echo '--- REPRODUCED: Lambda (Table-9-rq2-lambda.csv) ---' >> /workspace/repro.txt
cat /workspace/Table-9-rq2-lambda.csv >> /workspace/repro.txt 2>/dev/null || true
echo '--- REPRODUCED: Comprehension (Table-9-rq2-comp.csv) ---' >> /workspace/repro.txt
cat /workspace/Table-9-rq2-comp.csv >> /workspace/repro.txt 2>/dev/null || true
echo '--- REPRODUCED: MRF (Table-9-rq2-mrf.csv) ---' >> /workspace/repro.txt
cat /workspace/Table-9-rq2-mrf.csv >> /workspace/repro.txt 2>/dev/null || true
echo '</artisan_submit>' >> /workspace/repro.txt

echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
