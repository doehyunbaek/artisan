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
# Section 3: Reproduction commands
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh
# Extract values from generated CSV files
cd results
# For Lambda
L_OR1=$(awk -F, 'NR==2 {printf "%.2f", $1}' Table-9-rq2-lambda.csv)
L_EST1=$(awk -F, 'NR==2 {printf "%.2f", $2}' Table-9-rq2-lambda.csv)
L_STD1=$(awk -F, 'NR==2 {printf "%.2f", $3}' Table-9-rq2-lambda.csv)
L_T1=$(awk -F, 'NR==2 {printf "%.2f", $4}' Table-9-rq2-lambda.csv)
L_P1=$(awk -F, 'NR==2 {printf "%.2f", $5}' Table-9-rq2-lambda.csv)
L_OR2=$(awk -F, 'NR==3 {printf "%.2f", $1}' Table-9-rq2-lambda.csv)
L_EST2=$(awk -F, 'NR==3 {printf "%.2f", $2}' Table-9-rq2-lambda.csv)
L_STD2=$(awk -F, 'NR==3 {printf "%.2f", $3}' Table-9-rq2-lambda.csv)
L_T2=$(awk -F, 'NR==3 {printf "%.2f", $4}' Table-9-rq2-lambda.csv)
L_P2=$(awk -F, 'NR==3 {printf "%.2f", $5}' Table-9-rq2-lambda.csv)
# For Comprehension
C_OR1=$(awk -F, 'NR==2 {printf "%.2f", $1}' Table-9-rq2-comp.csv)
C_EST1=$(awk -F, 'NR==2 {printf "%.2f", $2}' Table-9-rq2-comp.csv)
C_STD1=$(awk -F, 'NR==2 {printf "%.2f", $3}' Table-9-rq2-comp.csv)
C_T1=$(awk -F, 'NR==2 {printf "%.2f", $4}' Table-9-rq2-comp.csv)
C_P1=$(awk -F, 'NR==2 {printf "%.2f", $5}' Table-9-rq2-comp.csv)
C_OR2=$(awk -F, 'NR==3 {printf "%.2f", $1}' Table-9-rq2-comp.csv)
C_EST2=$(awk -F, 'NR==3 {printf "%.2f", $2}' Table-9-rq2-comp.csv)
C_STD2=$(awk -F, 'NR==3 {printf "%.2f", $3}' Table-9-rq2-comp.csv)
C_T2=$(awk -F, 'NR==3 {printf "%.2f", $4}' Table-9-rq2-comp.csv)
C_P2=$(awk -F, 'NR==3 {printf "%.2f", $5}' Table-9-rq2-comp.csv)
# For MRF
M_OR=$(sed -n '2p' Table-9-rq2-mrf.csv | awk '{printf "%.2f", $1}')
M_EST=$(sed -n '3p' Table-9-rq2-mrf.csv | awk '{printf "%.2f", $1}')
M_STD=$(sed -n '4p' Table-9-rq2-mrf.csv | awk '{printf "%.2f", $1}')
M_T=$(sed -n '5p' Table-9-rq2-mrf.csv | awk '{printf "%.2f", $1}')
M_P=$(sed -n '6p' Table-9-rq2-mrf.csv | awk '{printf "%.2f", $1}')
# Output the table to /workspace/repro.txt
cat > /workspace/repro.txt <<OUTPUT
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | $L_OR1 |     $L_EST1 |     $L_STD1 |    $L_T1 |   $L_P1 |
| Compl.      | $L_OR2 |    $L_EST2 |     $L_STD2 |   $L_T2 |   $L_P2 |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | $C_OR1 |     $C_EST1 |     $C_STD1 |    $C_T1 |   $C_P1 |
| Compl.      | $C_OR2 |    $C_EST2 |     $C_STD2 |   $C_T2 |   $C_P2 |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | $M_OR |     $M_EST |     $M_STD |    $M_T |   $M_P |
OUTPUT
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
