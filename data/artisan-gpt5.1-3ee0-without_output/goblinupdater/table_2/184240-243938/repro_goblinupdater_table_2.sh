#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Demographics of our dataset of 107 Java projects**

|                           |    Q1 |  Q2 |   Q3 | min |     max |
| ------------------------- | ----: | --: | ---: | --: | ------: |
| (p)’s direct dependencies |   ?.? |   ? |    ? |   ? |      ?? |
| releases ((N_R))          |   ??? | ??? | ???? |  ?? |  ??,??? |
| libraries ((N_L))         |  ??.? |  ?? |  ??? |   ? |     ??? |
| dependency edges ((E_D))  | ???.? | ??? | ???? |   ? | ???,??? |
| versions edges ((E_V))    |   ??? | ??? | ???? |  ?? |  ??,??? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/13741330
# Section 3: Reproduction commands (populate from reviewed steps)
python - <<'PY'
import pandas as pd
from pathlib import Path

# Path to the executions data used in the population.ipynb notebook
csv_path = Path("ASE24_data_and_tools/ASE24_data_and_tools/results_data/execution/conf_1_global/executionsData.csv")

df = pd.read_csv(csv_path)

# Map the CSV columns to the row labels of Table 2
columns = [
    ("directDepNumber", "(p)’s direct dependencies"),
    ("releaseSize", "releases ((N_R))"),
    ("artifactSize", "libraries ((N_L))"),
    ("dependencySize", "dependency edges ((E_D))"),
    ("versionSize", "versions edges ((E_V))"),
]

# Compute descriptive statistics
stats = df[[c for c, _ in columns]].describe(percentiles=[0.25, 0.5, 0.75])

def fmt_int(value, thousand=False):
    v = int(round(float(value)))
    return f"{v:,}" if thousand else str(v)

def fmt_value(value, thousand=False):
    v = float(value)
    # Use one decimal when the value is non-integer (e.g., 4.5, 12.5, 114.5)
    if v.is_integer():
        return fmt_int(v, thousand=thousand)
    else:
        # For these dataset stats, non-integers are small counts, so no thousands separator needed
        return f"{v:.1f}"

rows = []

for col, label in columns:
    s = stats[col]
    q1 = s["25%"]
    q2 = s["50%"]
    q3 = s["75%"]
    mn = df[col].min()
    mx = df[col].max()

    # Use thousand separators for the large graph-size counts
    use_thousand = col in ("releaseSize", "dependencySize", "versionSize")

    row = {
        "label": label,
        "Q1": fmt_value(q1, thousand=use_thousand),
        "Q2": fmt_value(q2, thousand=use_thousand),
        "Q3": fmt_value(q3, thousand=use_thousand),
        "min": fmt_value(mn, thousand=use_thousand),
        "max": fmt_value(mx, thousand=use_thousand),
    }
    rows.append(row)

out_path = Path("/workspace/repro.txt")
with out_path.open("w", encoding="utf-8") as f:
    f.write("**Table 2: Demographics of our dataset of 107 Java projects**\n\n")
    f.write("|                           |    Q1 |  Q2 |   Q3 | min |     max |\n")
    f.write("| ------------------------- | ----: | --: | ---: | --: | ------: |\n")
    for row in rows:
        f.write(
            f"| {row['label']} | {row['Q1']} | {row['Q2']} | {row['Q3']} | {row['min']} | {row['max']} |\n"
        )
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
