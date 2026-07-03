#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ?.?? |     ?.?? |     ?.?? |    ?.?? |    ?.?? |
| Compl.      | ?.?? |    -?.?? |     ?.?? |   -?.?? |    ?.?? |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ?.?? |     ?.?? |     ?.?? |    ?.?? |    ?.?? |
| Compl.      | ?.?? |    -?.?? |     ?.?? |   -?.?? |    ?.?? |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ?.?? |     ?.?? |     ?.?? |    ?.?? |    ?.?? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts

# Pull the Docker image with R and required packages
docker pull mdipenta/rexp:latest

# Ensure a clean container name
docker rm -f funcconst-rexp-table9 >/dev/null 2>&1 || true

# Start a detached container as required
docker run -d --init --name funcconst-rexp-table9 --workdir /data -v"${PWD}":/data --entrypoint bash mdipenta/rexp:latest -c 'sleep infinity'

# Run the R analysis script inside the container to regenerate all tables, including Table 9
docker exec funcconst-rexp-table9 /bin/bash --noprofile --norc -c "R --no-save < FuncConstructs-Statistics.r"

# Extract Lambda coefficients (Table-9-rq2-lambda.csv)
L1_OR=$(awk -F, 'NR==2 {printf "%.2f",$1}' results/Table-9-rq2-lambda.csv)
L1_EST=$(awk -F, 'NR==2 {printf "%.2f",$2}' results/Table-9-rq2-lambda.csv)
L1_SE=$(awk -F, 'NR==2 {printf "%.2f",$3}' results/Table-9-rq2-lambda.csv)
L1_T=$(awk -F, 'NR==2 {printf "%.2f",$4}' results/Table-9-rq2-lambda.csv)
L1_P=$(awk -F, 'NR==2 {printf "%.2f",$5}' results/Table-9-rq2-lambda.csv)

L2_OR=$(awk -F, 'NR==3 {printf "%.2f",$1}' results/Table-9-rq2-lambda.csv)
L2_EST=$(awk -F, 'NR==3 {printf "%.2f",$2}' results/Table-9-rq2-lambda.csv)
L2_SE=$(awk -F, 'NR==3 {printf "%.2f",$3}' results/Table-9-rq2-lambda.csv)
L2_T=$(awk -F, 'NR==3 {printf "%.2f",$4}' results/Table-9-rq2-lambda.csv)
L2_P=$(awk -F, 'NR==3 {printf "%.2f",$5}' results/Table-9-rq2-lambda.csv)

# Extract Comprehension coefficients (Table-9-rq2-comp.csv)
C1_OR=$(awk -F, 'NR==2 {printf "%.2f",$1}' results/Table-9-rq2-comp.csv)
C1_EST=$(awk -F, 'NR==2 {printf "%.2f",$2}' results/Table-9-rq2-comp.csv)
C1_SE=$(awk -F, 'NR==2 {printf "%.2f",$3}' results/Table-9-rq2-comp.csv)
C1_T=$(awk -F, 'NR==2 {printf "%.2f",$4}' results/Table-9-rq2-comp.csv)
C1_P=$(awk -F, 'NR==2 {printf "%.2f",$5}' results/Table-9-rq2-comp.csv)

C2_OR=$(awk -F, 'NR==3 {printf "%.2f",$1}' results/Table-9-rq2-comp.csv)
C2_EST=$(awk -F, 'NR==3 {printf "%.2f",$2}' results/Table-9-rq2-comp.csv)
C2_SE=$(awk -F, 'NR==3 {printf "%.2f",$3}' results/Table-9-rq2-comp.csv)
C2_T=$(awk -F, 'NR==3 {printf "%.2f",$4}' results/Table-9-rq2-comp.csv)
C2_P=$(awk -F, 'NR==3 {printf "%.2f",$5}' results/Table-9-rq2-comp.csv)

# Extract MRF coefficients (Table-9-rq2-mrf.csv)
# File layout (no header row of names):
# NR==1: 'x'
# NR==2: OR
# NR==3: Estimate
# NR==4: StdError
# NR==5: t-value
# NR==6: p-value
M_OR=$(awk 'NR==2 {printf "%.2f",$1}' results/Table-9-rq2-mrf.csv)
M_EST=$(awk 'NR==3 {printf "%.2f",$1}' results/Table-9-rq2-mrf.csv)
M_SE=$(awk 'NR==4 {printf "%.2f",$1}' results/Table-9-rq2-mrf.csv)
M_T=$(awk 'NR==5 {printf "%.2f",$1}' results/Table-9-rq2-mrf.csv)
M_P=$(awk 'NR==6 {printf "%.2f",$1}' results/Table-9-rq2-mrf.csv)

# Build the reproduced Table 9 in Markdown format
cat > /workspace/repro.txt <<EOT
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | $L1_OR |     $L1_EST |     $L1_SE |    $L1_T |    $L1_P |
| Compl.      | $L2_OR |    $L2_EST |     $L2_SE |   $L2_T |    $L2_P |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | $C1_OR |     $C1_EST |     $C1_SE |    $C1_T |    $C1_P |
| Compl.      | $C2_OR |    $C2_EST |     $C2_SE |   $C2_T |    $C2_P |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | $M_OR |     $M_EST |     $M_SE |    $M_T |    $M_P |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
