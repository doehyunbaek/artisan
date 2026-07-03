#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
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

# Section 2: Artifact download (skip download if already present)
if [ -f "Understanding the Implications of Changes to Build Systems.zip" ] || [ -d "Understanding the Implications of Changes to Build Systems" ]; then
  echo "Artifact present, skipping artisan get."
else
  artisan get https://zenodo.org/records/13757411
fi

# Section 3: Reproduction commands
# Pull the analysis Docker image
docker pull mattienejati/bcia_analysis:ASE2024

# Remove any existing container named bcia_analysis to avoid conflicts
docker rm -f bcia_analysis 2>/dev/null || true

# Start the container (detached) and mount the package into /BCIA_Analysis
docker run -d --init --entrypoint bash --name bcia_analysis -v "$(pwd)":/BCIA_Analysis mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'

# Execute the empirical analysis script inside the running container, answering prompts non-interactively.
# The script lives in the nested package directory; redirect all output to /BCIA_Analysis/repro.txt (maps to host /workspace/repro.txt)
docker exec bcia_analysis /bin/bash --noprofile --norc -c "cd '/BCIA_Analysis/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems/4_Empirical_Analysis' && yes '' | python3 1_compute_empirical_results.py > /BCIA_Analysis/repro.txt 2>&1"

# Section 4: Formatting
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
