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
cd /workspace
# Fetch the Zenodo record metadata to discover the artifact file (id 10554377)
curl -L 'https://zenodo.org/api/records/10554377' -o record.json
# Download the actual artifact archive using the direct file URL from the record
curl -L 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content' -o ICSE2024-funcConstructs-Artifacts.zip
# Unpack the replication package
unzip -o ICSE2024-funcConstructs-Artifacts.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
# Pull the Docker image providing R and required packages
docker pull mdipenta/rexp:latest
# Start a long-lived container with the artifact mounted at /data
cd /workspace/ICSE2024-funcConstructs-Artifacts
docker run -d --init --entrypoint bash -v${PWD}:/data --name func_shell mdipenta/rexp:latest -c 'sleep infinity'
# Execute the R analysis script inside the running container to regenerate all tables, including Table 9
docker exec func_shell /bin/bash --noprofile --norc -c 'cd /data && R --no-save < FuncConstructs-Statistics.r'
# Collect the reproduced Table 9 results into /workspace/repro.txt
cd /workspace/ICSE2024-funcConstructs-Artifacts
{
  echo "**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**"
  echo
  echo "**Lambda (90 data points)**"
  echo
  # Convert CSV separator to Markdown table pipes for Lambda
  # CSV columns: "","OR","Value","Std. Error","t value","p value"
  # Map to header: Term | OR | Estimate | StdError | t-value | p-value
  echo "| Term        |   OR | Estimate | StdError | t-value | p-value |"
  echo "| ----------- | ---: | -------: | -------: | ------: | ------: |"
  tail -n +2 results/Table-9-rq2-lambda.csv | head -n 2 | awk -F',' '
    NR==1 {printf("| Usage Freq. | %.2f | %8.2f | %8.2f | %6.2f | %6.2f |\n",$2,$3,$4,$5,$6)}
    NR==2 {printf("| Compl.      | %.2f | %8.2f | %8.2f | %6.2f | %6.2f |\n",$2,$3,$4,$5,$6)}
  '
  echo
  echo "**Comprehension (120 data points)**"
  echo
  echo "| Term        |   OR | Estimate | StdError | t-value | p-value |"
  echo "| ----------- | ---: | -------: | -------: | ------: | ------: |"
  tail -n +2 results/Table-9-rq2-comp.csv | head -n 2 | awk -F',' '
    NR==1 {printf("| Usage Freq. | %.2f | %8.2f | %8.2f | %6.2f | %6.2f |\n",$2,$3,$4,$5,$6)}
    NR==2 {printf("| Compl.      | %.2f | %8.2f | %8.2f | %6.2f | %6.2f |\n",$2,$3,$4,$5,$6)}
  '
  echo
  echo "**MRF (103 data points)**"
  echo
  echo "| Term        |   OR | Estimate | StdError | t-value | p-value |"
  echo "| ----------- | ---: | -------: | -------: | ------: | ------: |"
  tail -n +2 results/Table-9-rq2-mrf.csv | head -n 1 | awk -F',' '
    NR==1 {printf("| Usage Freq. | %.2f | %8.2f | %8.2f | %6.2f | %6.2f |\n",$2,$3,$4,$5,$6)}
  '
} > /workspace/repro.txt
# Section 4: Formatting and submission block
cd /workspace
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
