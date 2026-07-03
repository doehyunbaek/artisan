#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -13.20 | 1696.36 | -0.01 | 0.99 |
| MainFactorProc | -0.26 | 0.47 | -0.56 | 0.99 |
| Usage Freq. | -0.83 | 0.44 | -1.87 | 0.30 |
| Approvals | 0.00 | 0.00 | -0.36 | 0.99 |
| StudentTrue | 14.38 | 1696.36 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace/artifact
# Download the artifact zip from Zenodo (record 10554377)
curl -L -o /workspace/artifact/ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content"
# Unzip
unzip -o /workspace/artifact/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/artifact/unzipped

# Section 3: Reproduction commands
# Pull the Docker image recommended by the authors
docker pull mdipenta/rexp:latest

# Ensure no existing container with same name
docker rm -f rexp_container >/dev/null 2>&1 || true

# Run the container detached (keeping /data mapped to the unzipped artifact)
docker run -d --init --entrypoint bash -v /workspace/artifact/unzipped/ICSE2024-funcConstructs-Artifacts:/data --name rexp_container mdipenta/rexp:latest -c 'sleep infinity'

# Execute the R analysis inside the container and capture logs
docker exec rexp_container /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r" > /workspace/repro.txt 2>&1

# Copy the produced Table 7 CSV to the workspace for submission (if present)
mkdir -p /workspace/repro_output
cp /workspace/artifact/unzipped/ICSE2024-funcConstructs-Artifacts/results/Table-7-RQ1-reduce.csv /workspace/repro_output/repro_table7.csv 2>/dev/null || true

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_output/submission_block.txt
if [ -f /workspace/repro_output/repro_table7.csv ]; then
  # Convert CSV to a simple markdown-like block for submission
  echo 'Table: Table-7-RQ1-reduce.csv' >> /workspace/repro_output/submission_block.txt
  cat /workspace/repro_output/repro_table7.csv >> /workspace/repro_output/submission_block.txt
else
  echo "Table-7-RQ1-reduce.csv not found. See /workspace/repro.txt for logs." >> /workspace/repro_output/submission_block.txt
fi
echo '</artisan_submit>' >> /workspace/repro_output/submission_block.txt

# Make the script executable
chmod +x /workspace/repro_pythonic_table_7.sh

echo "reproduction_script=/workspace/repro_pythonic_table_7.sh"
