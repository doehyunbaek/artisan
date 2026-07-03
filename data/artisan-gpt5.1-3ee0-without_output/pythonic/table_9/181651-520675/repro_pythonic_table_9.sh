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
# Run the R analysis inside the Dockerized R environment to regenerate results, including Table 9.
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
docker run -d --init --name func_rexp --entrypoint bash -v "$PWD":/data mdipenta/rexp:latest -c 'sleep infinity'
docker exec func_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Extract Table 9 values from the generated CSV files and build /workspace/repro.txt
results_dir="$PWD/results"
lambda_csv="$results_dir/Table-9-rq2-lambda.csv"
comp_csv="$results_dir/Table-9-rq2-comp.csv"
mrf_csv="$results_dir/Table-9-rq2-mrf.csv"

# Lambda rows
read lambda_or_u lambda_est_u lambda_se_u lambda_t_u lambda_p_u <<<"$(awk -F, 'NR==2{printf "%.2f %.2f %.2f %.2f %.2f",$1,$2,$3,$4,$5}' "$lambda_csv")"
read lambda_or_c lambda_est_c lambda_se_c lambda_t_c lambda_p_c <<<"$(awk -F, 'NR==3{printf "%.2f %.2f %.2f %.2f %.2f",$1,$2,$3,$4,$5}' "$lambda_csv")"

# Comprehension rows
read comp_or_u comp_est_u comp_se_u comp_t_u comp_p_u <<<"$(awk -F, 'NR==2{printf "%.2f %.2f %.2f %.2f %.2f",$1,$2,$3,$4,$5}' "$comp_csv")"
read comp_or_c comp_est_c comp_se_c comp_t_c comp_p_c <<<"$(awk -F, 'NR==3{printf "%.2f %.2f %.2f %.2f %.2f",$1,$2,$3,$4,$5}' "$comp_csv")"

# MRF row (single coefficient stored as a column of values)
read mrf_or mrf_est mrf_se mrf_t mrf_p <<<"$(awk -F, 'NR==2{or=$1} NR==3{est=$1} NR==4{se=$1} NR==5{t=$1} NR==6{p=$1} END{printf "%.2f %.2f %.2f %.2f %.2f",or,est,se,t,p}' "$mrf_csv")"

cat > /workspace/repro.txt <<EOT
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ${lambda_or_u} |     ${lambda_est_u} |     ${lambda_se_u} |    ${lambda_t_u} |    ${lambda_p_u} |
| Compl.      | ${lambda_or_c} |    ${lambda_est_c} |     ${lambda_se_c} |   ${lambda_t_c} |    ${lambda_p_c} |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ${comp_or_u} |     ${comp_est_u} |     ${comp_se_u} |    ${comp_t_u} |    ${comp_p_u} |
| Compl.      | ${comp_or_c} |    ${comp_est_c} |     ${comp_se_c} |   ${comp_t_c} |    ${comp_p_c} |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ${mrf_or} |     ${mrf_est} |     ${mrf_se} |    ${mrf_t} |    ${mrf_p} |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
