#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o 'Understanding the Implications of Changes to Build Systems.zip' https://zenodo.org/api/records/13757411/files/Understanding%20the%20Implications%20of%20Changes%20to%20Build%20Systems.zip/content
unzip 'Understanding the Implications of Changes to Build Systems.zip' -d 'Understanding the Implications of Changes to Build Systems'

PACKAGE_ROOT="/workspace/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems"
cd "$PACKAGE_ROOT"

docker pull mattienejati/bcia_analysis:ASE2024

docker run -d --init --name bcia_analysis_ASE2024_table3 --rm -v .:/BCIA_Analysis --entrypoint bash mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'

docker exec bcia_analysis_ASE2024_table3 /bin/bash --noprofile --norc -c 'cd /BCIA_Analysis/4_Empirical_Analysis && yes "" | python3 1_compute_empirical_results.py > empirical_run_full.log 2>&1'

docker kill bcia_analysis_ASE2024_table3 >/dev/null 2>&1 || true

echo '<artisan_submit>'
python3 - <<'PY' | tee /workspace/repro.txt
import csv
from pathlib import Path

root = Path("/workspace/Understanding the Implications of Changes to Build Systems/Understanding the Implications of Changes to Build Systems")
csv_path = root / "4_Empirical_Analysis" / "empirical_results" / "RQ2_table_3_Breadth_Magnitude_Interplay.csv"

with csv_path.open(newline="") as f:
    reader = csv.DictReader(f)
    data = {row["project"]: row for row in reader}

order = ["P1","P2","P3","P4","P5","P6","P7","P8","P9","P10","Overall"]

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
    alpha = 0.05
    if p > alpha:
        return f"p = {p:.2f} > α"
    elif p <= 1e-10:
        return "p ≪ α"
    else:
        return "p < α"

print("**Table 3: The correlations between magnitude and breadth.**")
print()
print("| Project | Median Mgn. | Median Brd. | Spearman ρ (α = 0.05) | Trendᵃ |")
print("| :---------: | ----------: | ----------: | ----------------------: | :----: |")

for key in order:
    row = data[key]
    med_mag = int(float(row["median_magnitude"]))
    med_brd = float(row["median_breadth"])
    rho = float(row["spearman_rho"])
    p = float(row["p_value"])

    # Use Unicode minus sign (U+2212) for negative correlations
    sign = "+" if rho >= 0 else "−"
    rho_str = f"{sign}{abs(rho):.3f}"
    p_str = classify_p(p)
    corr_cell = f"{rho_str} *({p_str})*"
    trend = trend_map[key]

    if key == "Overall":
        proj = "**Overall**"
        mag_str = f"**{med_mag}**"
        brd_str = f"**{med_brd:.3f}**"
        corr_cell = f"**{corr_cell}**"
        trend = f"**{trend}**"
    else:
        proj = key
        mag_str = f"{med_mag}"
        brd_str = f"{med_brd:.3f}"

    print(f"| {proj} | {mag_str} | {brd_str} | {corr_cell} | {trend} |")

print()
print("ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).")
PY
echo '</artisan_submit>'
