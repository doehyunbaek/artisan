#!/usr/bin/bash
# Section 1: Expected table - use the provided obfuscated table from the system
if [ -f /workspace/expected.md ]; then
    cp /workspace/expected.md /workspace/expected_table_3.md
else
    # Fallback to creating it from the paper if not available
    cat > /workspace/expected_table_3.md <<'EOTABLE'
**Table 3: The correlations between magnitude and breadth.**

|   Project   | Median Mgn. | Median Brd. |   Spearman ρ (α = 0.05) | Trendᵃ |
| :---------: | ----------: | ----------: | ----------------------: | :----: |
|      P1     |          ?? |       ?.??? | +?.??? *(p = ?.?? > α)* |   ～～   |
|      P2     |          ?? |       ?.??? |        +?.??? *(p ≪ α)* |   〜∿   |
|      P3     |          ?? |       ?.??? |        +?.??? *(p < α)* |   ——   |
|      P4     |          ?? |       ?.??? |        +?.??? *(p ≪ α)* |   〜∿   |
|      P5     |          ?? |       ?.??? |        +?.??? *(p ≪ α)* |   〜∿   |
|      P6     |          ?? |       ?.??? |        +?.??? *(p < α)* |   ——   |
|      P7     |           ? |       ?.??? | +?.??? *(p = ?.?? > α)* |   〜∼   |
|      P8     |           ? |       ?.??? | −?.??? *(p = ?.?? > α)* |   ——   |
|      P9     |           ? |       ?.??? |        +?.??? *(p ≪ α)* |   〜∿   |
|     P10     |          ?? |       ?.??? |        +?.??? *(p < α)* |   〜∿   |
| **Overall** |      **??** |   **?.???** |    **+?.??? *(p ≪ α)*** | **〜∿** |

ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).
EOTABLE
fi
# Section 2: Artifact download
artisan get https://zenodo.org/records/13757411
# Section 3: Reproduction commands
# Pull Docker images
docker pull mattienejati/bcia_analysis:ASE2024
docker pull mattienejati/buiscout:ASE2024
# Start analysis container with volume mount
cd "Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems"
container_id=$(docker run -d --init -v "$PWD:/BCIA_Analysis" --entrypoint bash mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity')
# Run the empirical analysis script to generate Table 3
docker exec $container_id /bin/bash --noprofile --norc -c "cd '/BCIA_Analysis/4_Empirical_Analysis' && yes '' | head -30 | python3 1_compute_empirical_results.py > /BCIA_Analysis/repro_output.txt 2>&1"
# Extract Table 3 data from the generated CSV
docker exec $container_id /bin/bash --noprofile --norc -c "cat '/BCIA_Analysis/4_Empirical_Analysis/empirical_results/RQ2_table_3_Breadth_Magnitude_Interplay.csv'" > /workspace/repro.txt
# Clean up container
docker stop $container_id
docker rm $container_id
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected_table_3.md --repro /workspace/repro.txt
echo '</artisan_submit>'
