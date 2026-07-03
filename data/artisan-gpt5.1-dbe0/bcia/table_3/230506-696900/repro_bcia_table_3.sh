#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table template (P8 Spearman cell left with ? placeholders)
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The correlations between magnitude and breadth.**

| Project | Median Mgn. | Median Brd. | Spearman ρ (α = 0.05) | Trendᵃ |
| :---------: | ----------: | ----------: | ----------------------: | :----: |
| P1 | 11 | 0.933 | +0.054 *(p = 0.11 > α)* | ～～ |
| P2 | 18 | 0.957 | +0.313 *(p ≪ α)* | 〜∿ |
| P3 | 27 | 1.000 | +0.092 *(p < α)* | —— |
| P4 | 19 | 0.621 | +0.492 *(p ≪ α)* | 〜∿ |
| P5 | 21 | 0.649 | +0.343 *(p ≪ α)* | 〜∿ |
| P6 | 14 | 1.000 | +0.099 *(p < α)* | —— |
| P7 | 6 | 1.000 | +0.038 *(p = 0.28 > α)* | 〜∼ |
| P8 | 4 | 0.000 | −?.??? *(p = ?.?? > α)* | —— |
| P9 | 6 | 0.500 | +0.463 *(p ≪ α)* | 〜∿ |
| P10 | 25 | 0.978 | +0.177 *(p < α)* | 〜∿ |
| **Overall** | **14** | **0.955** | **+0.272 *(p ≪ α)*** | **〜∿** |

ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).
EOTABLE

# Section 2: Artifact download
cd /workspace
artisan get https://zenodo.org/records/13757411

# Section 3: Reproduction commands
cd "/workspace/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems"

# Pull the analysis Docker image
docker pull mattienejati/bcia_analysis:ASE2024

# Run the analysis container in the background with the package mounted
docker run -d --init --name bcia_analysis --entrypoint bash -v "$(pwd)":/BCIA_Analysis mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'

# Execute the empirical analysis script non-interactively to generate Table 3 CSV
docker exec bcia_analysis /bin/bash --noprofile --norc -c "cd /BCIA_Analysis/4_Empirical_Analysis && yes '' | python3 1_compute_empirical_results.py"

# Use the generated CSV to build the markdown table programmatically (including full digits for P8)
python3 - <<'PY' > /workspace/repro.txt
import csv
from pathlib import Path

csv_path = Path(
    "/workspace/Understanding the Implications of Changes to Build Systems/"
    "Understanding the Implications of Changes to Build Systems/"
    "4_Empirical_Analysis/empirical_results/"
    "RQ2_table_3_Breadth_Magnitude_Interplay.csv"
)

rows = []
with csv_path.open(newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

trend_map = {
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

def format_spearman(rho: float, p: float) -> str:
    alpha = 0.05
    sign = "+" if rho >= 0 else "\u2212"  # U+2212 minus
    rho_abs = f"{abs(rho):.3f}"
    if p >= alpha:
        p_str = f"p = {p:.2f} > α"
    elif p < 1e-10:
        p_str = "p ≪ α"
    else:
        p_str = "p < α"
    return f"{sign}{rho_abs} *({p_str})*"

lines = []
lines.append("**Table 3: The correlations between magnitude and breadth.**")
lines.append("")
lines.append("| Project | Median Mgn. | Median Brd. | Spearman ρ (α = 0.05) | Trendᵃ |")
lines.append("| :---------: | ----------: | ----------: | ----------------------: | :----: |")

for r in rows:
    proj = r["project"]
    mag = int(round(float(r["median_magnitude"])))
    brd = float(r["median_breadth"])
    rho = float(r["spearman_rho"])
    p = float(r["p_value"])
    brd_str = f"{brd:.3f}"
    trend = trend_map[proj]
    spearman_cell = format_spearman(rho, p)

    if proj == "Overall":
        line = f"| **Overall** | **{mag}** | **{brd_str}** | **{spearman_cell}** | **{trend}** |"
    else:
        line = f"| {proj} | {mag} | {brd_str} | {spearman_cell} | {trend} |"
    lines.append(line)

lines.append("")
lines.append(
    "ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis "
    "represents the breadth and the horizontal axis represents the magnitude "
    "(log scale)."
)

print("\n".join(lines))
PY

# Stop and remove the container to clean up
docker stop bcia_analysis
docker rm bcia_analysis

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
