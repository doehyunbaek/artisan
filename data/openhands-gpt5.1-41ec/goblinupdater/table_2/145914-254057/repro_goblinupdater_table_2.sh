#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Demographics of our dataset of 107 Java projects**

|                           |    Q1 |  Q2 |   Q3 | min |     max |
| ------------------------- | ----: | --: | ---: | --: | ------: |
| (p)’s direct dependencies |   4.5 |   7 |    9 |   2 |      22 |
| releases ((N_R))          |   138 | 336 | 2771 |  16 |  39,474 |
| libraries ((N_L))         |  12.5 |  40 |  134 |   4 |     960 |
| dependency edges ((E_D))  | 114.5 | 394 | 7066 |   9 | 141,429 |
| versions edges ((E_V))    |   137 | 335 | 2770 |  15 |  39,473 |

EOTABLE
# Section 2: Artifact download
curl -L -o ASE24_data_and_tools.zip "https://zenodo.org/records/13741330/files/ASE24_data_and_tools.zip?download=1"
unzip -o ASE24_data_and_tools.zip
curl -L -o ASE24_README.md "https://zenodo.org/records/13741330/files/README.md?download=1"
cp ASE24_README.md README.md
# Section 3: Reproduction commands (populate from reviewed steps)
# They should output the reproduction results to /workspace/repro.txt
python - << 'PY'
import pandas as pd
from pathlib import Path

root = Path('/workspace')
csv_path = root / 'ASE24_data_and_tools' / 'results_data' / 'execution' / 'conf_1_global' / 'executionsData.csv'

if not csv_path.is_file():
    raise SystemExit(f"CSV file not found: {csv_path}")

df = pd.read_csv(csv_path)
columns_of_interest = ['directDepNumber', 'releaseSize', 'artifactSize', 'dependencySize', 'versionSize']
labels = {
    'directDepNumber': "(p)'s direct dependencies",
    'releaseSize': 'releases ((N_R))',
    'artifactSize': 'libraries ((N_L))',
    'dependencySize': 'dependency edges ((E_D))',
    'versionSize': 'versions edges ((E_V))',
}

data = df[columns_of_interest]
stat = data.describe(percentiles=[0.25, 0.5, 0.75])
stat.loc['min'] = data.min()
stat.loc['max'] = data.max()

def format_value(v):
    if v is None:
        return ''
    try:
        v_float = float(v)
    except Exception:
        return str(v)
    if not v_float.is_integer():
        # keep one decimal for non-integer values like 4.5
        s = f"{v_float:.1f}".rstrip('0').rstrip('.')
        return s
    v_int = int(round(v_float))
    if abs(v_int) >= 10000:
        return f"{v_int:,}"
    return str(v_int)

lines = []
lines.append("**Table 2: Demographics of our dataset of 107 Java projects**")
lines.append("")
lines.append("|                           |    Q1 |  Q2 |   Q3 | min |     max |")
lines.append("| ------------------------- | ----: | --: | ---: | --: | ------: |")

row_order = [
    'directDepNumber',
    'releaseSize',
    'artifactSize',
    'dependencySize',
    'versionSize',
]

for col in row_order:
    label = labels[col]
    q1 = format_value(stat.loc['25%', col])
    q2 = format_value(stat.loc['50%', col])
    q3 = format_value(stat.loc['75%', col])
    vmin = format_value(stat.loc['min', col])
    vmax = format_value(stat.loc['max', col])
    line = f"| {label:<25} | {q1:>4} | {q2:>3} | {q3:>4} | {vmin:>3} | {vmax:>7} |"
    lines.append(line)

output_path = root / 'repro.txt'
output_path.write_text("\n".join(lines) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
