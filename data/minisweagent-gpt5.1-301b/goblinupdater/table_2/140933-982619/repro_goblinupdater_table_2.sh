#!/usr/bin/bash
set -euo pipefail

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
mkdir -p /workspace
cd /workspace
if [ ! -f ASE24_data_and_tools.zip ]; then
  curl -L "https://zenodo.org/api/records/13741330/files/ASE24_data_and_tools.zip/content" -o ASE24_data_and_tools.zip
fi
if [ ! -d ASE24_data_and_tools ]; then
  unzip -q ASE24_data_and_tools.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Use the same approach as results_data/notebook/population.ipynb:
# load executionsData.csv (conf_1_global) and compute describe(percentiles=[0.25,0.5,0.75])
python - << 'PY'
import pandas as pd
from pathlib import Path

root = Path("/workspace/ASE24_data_and_tools")
csv_path = root / "results_data" / "execution" / "conf_1_global" / "executionsData.csv"

df = pd.read_csv(csv_path)
columns_of_interest = ['directDepNumber', 'releaseSize', 'artifactSize', 'dependencySize', 'versionSize']
data = df[columns_of_interest]

# Describe will give count, mean, std, min, 25%, 50%, 75%, max
descriptive_stats = data.describe(percentiles=[0.25, 0.5, 0.75])
min_values = data.min()
max_values = data.max()
descriptive_stats.loc['min'] = min_values
descriptive_stats.loc['max'] = max_values

# Extract the needed statistics
q1 = descriptive_stats.loc['25%']
q2 = descriptive_stats.loc['50%']
q3 = descriptive_stats.loc['75%']
mn = descriptive_stats.loc['min']
mx = descriptive_stats.loc['max']

# Helper for formatting integers with thousands separators and trimming .0
def fmt_number(val, integer=True):
    if integer:
        v = int(round(val))
        return f"{v:,d}"
    else:
        # keep one decimal for non-integers (like 4.5, 12.5, 114.5)
        v = round(float(val), 1)
        # remove trailing .0
        if abs(v - int(v)) < 1e-9:
            return f"{int(v)}"
        return f"{v}"

rows = [
    (
        "(p)’s direct dependencies",
        fmt_number(q1['directDepNumber'], integer=False),
        fmt_number(q2['directDepNumber'], integer=True),
        fmt_number(q3['directDepNumber'], integer=True),
        fmt_number(mn['directDepNumber'], integer=True),
        fmt_number(mx['directDepNumber'], integer=True),
    ),
    (
        "releases ((N_R))",
        fmt_number(q1['releaseSize'], integer=True),
        fmt_number(q2['releaseSize'], integer=True),
        fmt_number(q3['releaseSize'], integer=True),
        fmt_number(mn['releaseSize'], integer=True),
        fmt_number(mx['releaseSize'], integer=True),
    ),
    (
        "libraries ((N_L))",
        fmt_number(q1['artifactSize'], integer=False),
        fmt_number(q2['artifactSize'], integer=True),
        fmt_number(q3['artifactSize'], integer=True),
        fmt_number(mn['artifactSize'], integer=True),
        fmt_number(mx['artifactSize'], integer=True),
    ),
    (
        "dependency edges ((E_D))",
        fmt_number(q1['dependencySize'], integer=False),
        fmt_number(q2['dependencySize'], integer=True),
        fmt_number(q3['dependencySize'], integer=True),
        fmt_number(mn['dependencySize'], integer=True),
        fmt_number(mx['dependencySize'], integer=True),
    ),
    (
        "versions edges ((E_V))",
        fmt_number(q1['versionSize'], integer=False),
        fmt_number(q2['versionSize'], integer=True),
        fmt_number(q3['versionSize'], integer=True),
        fmt_number(mn['versionSize'], integer=True),
        fmt_number(mx['versionSize'], integer=True),
    ),
]

out_lines = []
out_lines.append("**Reproduced Table 2: Demographics of our dataset of 107 Java projects**")
out_lines.append("")
out_lines.append("|                           |    Q1 |  Q2 |   Q3 | min |     max |")
out_lines.append("| ------------------------- | ----: | --: | ---: | --: | ------: |")
for label, q1v, q2v, q3v, minv, maxv in rows:
    out_lines.append(f"| {label} | {q1v:>4} | {q2v:>3} | {q3v:>4} | {minv:>3} | {maxv:>6} |")

Path("/workspace/repro.txt").write_text("\n".join(out_lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
