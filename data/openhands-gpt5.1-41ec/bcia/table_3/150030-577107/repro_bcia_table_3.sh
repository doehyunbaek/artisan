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
cd /workspace
curl -L 'https://zenodo.org/api/records/13757411/files/Understanding%20the%20Implications%20of%20Changes%20to%20Build%20Systems.zip/content' -o build_systems_artifact.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
unzip -o build_systems_artifact.zip
cd "/workspace/Understanding the Implications of Changes to Build Systems"
# Ensure required Docker images are available
docker pull mattienejati/bcia_analysis:ASE2024
docker pull mattienejati/buiscout:ASE2024
# Start analysis container in the recommended detached mode
docker run -d --init --rm --name bcia_analysis_table3 -v .:/BCIA_Analysis --entrypoint bash mattienejati/bcia_analysis:ASE2024 -c 'sleep infinity'
# Run empirical results script inside the container (auto-confirm prompts)
docker exec bcia_analysis_table3 /bin/bash --noprofile --norc -c "cd 4_Empirical_Analysis && yes '' | python3 1_compute_empirical_results.py"
# Copy reproduced Table 3 CSV out of the container
docker exec bcia_analysis_table3 /bin/bash --noprofile --norc -c "cp 4_Empirical_Analysis/empirical_results/RQ2_table_3_Breadth_Magnitude_Interplay.csv /BCIA_Analysis/RQ2_table_3_Breadth_Magnitude_Interplay.csv"
# Stop the analysis container (it will be removed due to --rm)
docker stop bcia_analysis_table3 || true
# Generate /workspace/repro.txt from the reproduced CSV
cd /workspace
python - << 'PY'
import csv
from pathlib import Path

package_root = Path('/workspace/Understanding the Implications of Changes to Build Systems')
csv_path = package_root / 'RQ2_table_3_Breadth_Magnitude_Interplay.csv'
if not csv_path.exists():
    # Fallback to location inside empirical_results if direct copy path differs
    csv_path = package_root / '4_Empirical_Analysis' / 'empirical_results' / 'RQ2_table_3_Breadth_Magnitude_Interplay.csv'

rows = []
with csv_path.open(newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

trend_map = {
    'P1': '～～',
    'P2': '〜∿',
    'P3': '——',
    'P4': '〜∿',
    'P5': '〜∿',
    'P6': '——',
    'P7': '〜∼',
    'P8': '——',
    'P9': '〜∿',
    'P10': '〜∿',
    'Overall': '〜∿',
}

lines = []
lines.append('**Table 3: The correlations between magnitude and breadth.**')
lines.append('')
lines.append('|   Project   | Median Mgn. | Median Brd. |   Spearman ρ (α = 0.05) | Trendᵃ |')
lines.append('| :---------: | ----------: | ----------: | ----------------------: | :----: |')

for row in rows:
    proj = row['project']
    med_mag = int(round(float(row['median_magnitude'])))
    med_brd = float(row['median_breadth'])
    rho = float(row['spearman_rho'])
    p = float(row['p_value'])

    rho_str = f"{rho:+.3f}"
    if p >= 0.05:
        p_str = f"p = {p:.2f} > α"
    elif p <= 1e-10:
        p_str = "p ≪ α"
    else:
        p_str = "p < α"
    stat_str = f"{rho_str} *(" + p_str + ")*"

    trend = trend_map[proj]

    if proj == 'Overall':
        proj_disp = '**Overall**'
        med_mag_disp = f'**{med_mag}**'
        med_brd_disp = f'**{med_brd:.3f}**'
        stat_disp = f'**{stat_str}**'
        trend_disp = f'**{trend}**'
    else:
        proj_disp = proj
        med_mag_disp = f'{med_mag:d}'
        med_brd_disp = f'{med_brd:.3f}'
        stat_disp = stat_str
        trend_disp = trend

    line = f"| {proj_disp:^9} | {med_mag_disp:>10} | {med_brd_disp:>10} | {stat_disp:>22} | {trend_disp:^6} |"
    lines.append(line)

lines.append('')
lines.append('ᵃ LOWESS (Locally Weighted Scatterplot Smoothing); the vertical axis represents the breadth and the horizontal axis represents the magnitude (log scale).')

Path('/workspace/repro.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
