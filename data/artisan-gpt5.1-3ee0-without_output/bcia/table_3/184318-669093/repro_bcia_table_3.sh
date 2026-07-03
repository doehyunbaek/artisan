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
artisan get https://zenodo.org/records/13757411
# Section 3: Reproduction commands (populate from reviewed steps)
# Prepare and run the analysis Docker container, then regenerate Table 3
docker rm -f bcia_analysis >/dev/null 2>&1 || true
docker pull mattienejati/bcia_analysis:ASE2024
docker run -d --init --name bcia_analysis --entrypoint bash -v "/workspace/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems":/BCIA_Analysis mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'
docker exec bcia_analysis /bin/bash --noprofile --norc -c 'cd /BCIA_Analysis/4_Empirical_Analysis && yes "" | python3 1_compute_empirical_results.py'
docker stop bcia_analysis >/dev/null 2>&1 || true
docker rm -f bcia_analysis >/dev/null 2>&1 || true

# Convert the generated CSV for Table 3 into the Markdown table at /workspace/repro.txt
python - << 'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems/4_Empirical_Analysis/empirical_results/RQ2_table_3_Breadth_Magnitude_Interplay.csv")
rows = {}
with csv_path.open(newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows[r["project"]] = r

order = ["P1","P2","P3","P4","P5","P6","P7","P8","P9","P10","Overall"]
trend = {
    "P1": "～～",
    "P2": "〜∿",
    "P3": "——",
    "P4": "〜∿",
    "P5": "〜∿",
    "P6": "——",
    "P7": "〜∼",
    "P8": "——",
    "P9": "〜∿",
    "P10": "〜∿",
    "Overall": "〜∿",
}

def format_row(key):
    r = rows[key]
    median_magnitude = int(round(float(r["median_magnitude"])))
    median_breadth = f'{float(r["median_breadth"]):.3f}'
    rho = float(r["spearman_rho"])
    p = float(r["p_value"])
    sign = "+" if rho >= 0 else "−"
    rho_str = f"{abs(rho):.3f}"
    if p > 0.05:
        p_str = f"p = {p:.2f} > α"
    elif p < 1e-10:
        p_str = "p ≪ α"
    else:
        p_str = "p < α"
    spearman = f"{sign}{rho_str} *({p_str})*"
    return median_magnitude, median_breadth, spearman

out_path = Path("/workspace/repro.txt")
with out_path.open("w", encoding="utf-8") as out:
    out.write("**Table 3: The correlations between magnitude and breadth.**\n\n")
    out.write("|   Project   | Median Mgn. | Median Brd. |   Spearman ρ (α = 0.05) | Trendᵃ |\n")
    out.write("| :---------: | ----------: | ----------: | ----------------------: | :----: |\n")

    for key in order[:-1]:
        mgn, brd, spearman = format_row(key)
        out.write(f"|      {key}     |{mgn:11d} |{float(brd):11.3f} | {spearman:>22} |   {trend[key]}   |\n")

    key = "Overall"
    mgn, brd, spearman = format_row(key)
    out.write(f"| **{key}** |      **{mgn}** |   **{float(brd):.3f}** |    **{spearman}** | **{trend[key]}** |\n\n")
    out.write("ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
