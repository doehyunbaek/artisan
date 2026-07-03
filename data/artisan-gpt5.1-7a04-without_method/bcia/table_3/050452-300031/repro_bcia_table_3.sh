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
# 3a. Use Docker image to run empirical analysis and generate the Table 3 CSV
HOST_ROOT="/workspace/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems"
docker pull mattienejati/bcia_analysis:ASE2024
docker rm -f bcia_analysis_ase2024 2>/dev/null || true
docker run -d --init --entrypoint bash -v "${HOST_ROOT}":/BCIA_Analysis --name bcia_analysis_ase2024 mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'
docker exec bcia_analysis_ase2024 /bin/bash --noprofile --norc -c "cd /BCIA_Analysis/4_Empirical_Analysis && printf '\n%.0s' {1..20} | python3 1_compute_empirical_results.py > empirical_results/run_empirical.log 2>&1"
docker stop bcia_analysis_ase2024 >/dev/null
# 3b. Parse the generated CSV and render the table as Markdown to /workspace/repro.txt
cd /workspace || exit 1
python - <<'PY'
import csv
import pathlib

alpha = 0.05

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

def classify_p(p: float) -> str:
    if p > alpha:
        return f"p = {p:.2f} > α"
    elif p < 1e-10:
        return "p ≪ α"
    else:
        return "p < α"

base = pathlib.Path(".")
matches = list(base.rglob("RQ2_table_3_Breadth_Magnitude_Interplay.csv"))
if not matches:
    raise SystemExit("Could not find RQ2_table_3_Breadth_Magnitude_Interplay.csv")
csv_path = matches[0]

rows = {}
with csv_path.open(newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows[row["project"]] = row

ordered = ["P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10", "Overall"]

lines = []
lines.append("**Table 3: The correlations between magnitude and breadth.**\n")
lines.append("\n")
lines.append("|   Project   | Median Mgn. | Median Brd. |   Spearman ρ (α = 0.05) | Trendᵃ |\n")
lines.append("| :---------: | ----------: | ----------: | ----------------------: | :----: |\n")

for proj in ordered:
    r = rows[proj]
    mag = int(round(float(r["median_magnitude"])))
    brd = float(r["median_breadth"])
    rho = float(r["spearman_rho"])
    p = float(r["p_value"])

    brd_str = f"{brd:.3f}"
    sign = "+" if rho >= 0 else "−"
    rho_str = f"{sign}{abs(rho):.3f}"
    p_str = classify_p(p)
    rho_col = f"{rho_str} *({p_str})*"
    trend = trend_map[proj]

    if proj == "Overall":
        proj_cell = "**Overall**"
        mag_cell = f"**{mag}**"
        brd_cell = f"**{brd_str}**"
        rho_cell = f"**{rho_col}**"
        trend_cell = f"**{trend}**"
    else:
        proj_cell = proj
        mag_cell = str(mag)
        brd_cell = brd_str
        rho_cell = rho_col
        trend_cell = trend

    line = f"| {proj_cell:>9} | {mag_cell:>10} | {brd_cell:>10} | {rho_cell:>22} | {trend_cell:^6} |"
    lines.append(line + "\n")

lines.append("\n")
lines.append("ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).\n")

with open("/workspace/repro.txt", "w", encoding="utf-8") as out_f:
    out_f.writelines(lines)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
