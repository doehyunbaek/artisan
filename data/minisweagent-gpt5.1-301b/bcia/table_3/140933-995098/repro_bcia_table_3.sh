#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The correlations between magnitude and breadth.**

|   Project   | Median Mgn. | Median Brd. |   Spearman ρ (α = 0.05) | Trendᵃ |
| :---------: | ----------: | ----------: | ----------------------: | :----: |
|      P1     |          11 |       0.933 | +0.054 *(p = 0.11 > α)* |   ～～   |
|      P2     |          18 |       0.957 |        +0.313 *(p ≪ α)* |   〜∿   |
|      P3     |          27 |       1.000 |        +0.092 *(p < α)* |   ——   |
|      P4     |          19 |       0.621 |        +0.492 *(p ≪ α)* |   〜∿   |
|      P5     |          21 |       0.649 |        +0.343 *(p ≪ α)* |   〜∿   |
|      P6     |          14 |       1.000 |        +0.099 *(p < α)* |   ——   |
|      P7     |           6 |       1.000 | +0.038 *(p = 0.28 > α)* |   〜∼   |
|      P8     |           4 |       0.000 | −0.002 *(p = 0.96 > α)* |   ——   |
|      P9     |           6 |       0.500 |        +0.463 *(p ≪ α)* |   〜∿   |
|     P10     |          25 |       0.978 |        +0.177 *(p < α)* |   〜∿   |
| **Overall** |      **14** |   **0.955** |    **+0.272 *(p ≪ α)*** | **〜∿** |

ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).

EOTABLE

# Section 2: Artifact download
mkdir -p /workspace
cd /workspace || exit 1

# Download the main replication-package archive from Zenodo if not already present
if [ ! -f "Understanding_the_Implications_of_Changes_to_Build_Systems.zip" ]; then
  curl -L -o 'Understanding_the_Implications_of_Changes_to_Build_Systems.zip' \
    'https://zenodo.org/api/records/13757411/files/Understanding%20the%20Implications%20of%20Changes%20to%20Build%20Systems.zip/content'
fi

# Unpack the replication package (PACKAGE_ROOT) if needed
if [ ! -d "Understanding the Implications of Changes to Build Systems" ]; then
  unzip -q 'Understanding_the_Implications_of_Changes_to_Build_Systems.zip'
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Pull the analysis Docker image used in the artifact
docker pull mattienejati/bcia_analysis:ASE2024

# Start a long-lived analysis container (if not already running), mounting PACKAGE_ROOT as /BCIA_Analysis
if ! docker ps --format '{{.Names}}' | grep -q '^bcia_analysis_table_3$'; then
  docker run -d --init --entrypoint bash \
    --name bcia_analysis_table_3 \
    -v "/workspace/Understanding the Implications of Changes to Build Systems":/BCIA_Analysis \
    mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'
fi

# Run the empirical analysis script inside the container to regenerate all results, including Table 3
docker exec bcia_analysis_table_3 /bin/bash --noprofile --norc -c \
  "cd /BCIA_Analysis/4_Empirical_Analysis && yes '' | python3 1_compute_empirical_results.py"

# Copy the reproduced Table 3 CSV to /workspace/repro.txt as the reproduction output
cp "/workspace/Understanding the Implications of Changes to Build Systems/4_Empirical_Analysis/empirical_results/RQ2_table_3_Breadth_Magnitude_Interplay.csv" \
  /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
