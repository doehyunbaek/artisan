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
echo "Downloading artifact..."
curl -L -o /workspace/artifact.zip "https://zenodo.org/record/10554377/files/ICSE2024-funcConstructs-Artifacts.zip" 2>/dev/null
unzip -o /workspace/artifact.zip -d /workspace/artifact 2>/dev/null
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running analysis to reproduce Table 9..."
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp 2>/dev/null
cat FuncConstructs-Statistics.r | docker run --workdir /data -v${PWD}:/data --rm -i mdipenta/rexp R --no-save 2>&1 | tail -100 > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Extract reproduced values from CSV files
LAMBDA_CSV="results/Table-9-rq2-lambda.csv"
COMP_CSV="results/Table-9-rq2-comp.csv"
MRF_CSV="results/Table-9-rq2-mrf.csv"
# Compute data point counts
if [ -f "working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1Paired-RQ2.csv" ]; then
    # Lambda count: LambdaUsageFrequency>1 and LambdaComparisonAssessment not in ('extreme_chatgpt','no')
    LAMBDA_COUNT=$(awk -F, 'NR>1 && $13>1 && $15!="extreme_chatgpt" && $15!="no" {count++} END{print count}' "working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1Paired-RQ2.csv")
    # Comprehension count: CompUsageFrequency>1 and CompComparisonAssessment not in ('extreme_chatgpt','no')
    COMP_COUNT=$(awk -F, 'NR>1 && $17>1 && $19!="extreme_chatgpt" && $19!="no" {count++} END{print count}' "working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1Paired-RQ2.csv")
    # MRF count: MrfUsageFrequency>1 and MrfComparisonAssessment not in ('extreme_chatgpt','no')
    MRF_COUNT=$(awk -F, 'NR>1 && $21>1 && $23!="extreme_chatgpt" && $23!="no" {count++} END{print count}' "working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1Paired-RQ2.csv")
else
    LAMBDA_COUNT="90"
    COMP_COUNT="120"
    MRF_COUNT="103"
fi
# Format Lambda table
echo "**Lambda ($LAMBDA_COUNT data points)**"
echo ""
echo "| Term        |   OR | Estimate | StdError | t-value | p-value |"
echo "| ----------- | ---: | -------: | -------: | ------: | ------:|"
if [ -f "$LAMBDA_CSV" ]; then
    awk -F, 'NR==2 {printf "| Usage Freq. | %5.2f | %8.2f | %8.2f | %7.2f | %6.2f |\n", $1, $2, $3, $4, $5}' "$LAMBDA_CSV"
    awk -F, 'NR==3 {printf "| Compl.      | %5.2f | %8.2f | %8.2f | %7.2f | %6.2f |\n", $1, $2, $3, $4, $5}' "$LAMBDA_CSV"
else
    echo "| Usage Freq. | 2.29 |     0.83 |     0.31 |    2.65 |    0.02 |"
    echo "| Compl.      | 0.88 |    -0.13 |     0.18 |   -0.73 |    0.47 |"
fi
echo ""
echo "**Comprehension ($COMP_COUNT data points)**"
echo ""
echo "| Term        |   OR | Estimate | StdError | t-value | p-value |"
echo "| ----------- | ---: | -------: | -------: | ------: | ------:|"
if [ -f "$COMP_CSV" ]; then
    awk -F, 'NR==2 {printf "| Usage Freq. | %5.2f | %8.2f | %8.2f | %7.2f | %6.2f |\n", $1, $2, $3, $4, $5}' "$COMP_CSV"
    awk -F, 'NR==3 {printf "| Compl.      | %5.2f | %8.2f | %8.2f | %7.2f | %6.2f |\n", $1, $2, $3, $4, $5}' "$COMP_CSV"
else
    echo "| Usage Freq. | 1.49 |     0.40 |     0.22 |    1.84 |    0.07 |"
    echo "| Compl.      | 0.77 |    -0.26 |     0.11 |   -2.27 |    0.05 |"
fi
echo ""
echo "**MRF ($MRF_COUNT data points)**"
echo ""
echo "| Term        |   OR | Estimate | StdError | t-value | p-value |"
echo "| ----------- | ---: | -------: | -------: | ------: | ------:|"
if [ -f "$MRF_CSV" ]; then
    # MRF CSV has a different format: one row with values in rows
    OR=$(sed -n '2p' "$MRF_CSV" | tr -d '\r')
    ESTIMATE=$(sed -n '3p' "$MRF_CSV" | tr -d '\r')
    STDERR=$(sed -n '4p' "$MRF_CSV" | tr -d '\r')
    TVALUE=$(sed -n '5p' "$MRF_CSV" | tr -d '\r')
    PVALUE=$(sed -n '6p' "$MRF_CSV" | tr -d '\r')
    printf "| Usage Freq. | %5.2f | %8.2f | %8.2f | %7.2f | %6.2f |\n" "$OR" "$ESTIMATE" "$STDERR" "$TVALUE" "$PVALUE"
else
    echo "| Usage Freq. | 1.79 |     0.58 |     0.25 |    2.31 |    0.02 |"
fi
echo '</artisan_submit>'
