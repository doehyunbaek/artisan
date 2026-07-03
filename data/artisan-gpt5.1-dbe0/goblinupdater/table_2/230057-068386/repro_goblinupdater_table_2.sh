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
artisan get https://zenodo.org/records/13741330

# Section 3: Reproduction commands (populate from reviewed steps)
python - << 'PY' > /workspace/repro.txt
import csv, math, pathlib

path = pathlib.Path("ASE24_data_and_tools/ASE24_data_and_tools/results_data/execution/conf_1_global/executionsData.csv")

with path.open(newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

cols = {
    "(p)’s direct dependencies": "directDepNumber",
    "releases ((N_R))": "releaseSize",
    "libraries ((N_L))": "artifactSize",
    "dependency edges ((E_D))": "dependencySize",
    "versions edges ((E_V))": "versionSize",
}

def series(colname):
    return sorted(float(r[colname]) for r in rows)

def quantile(vals, q):
    n = len(vals)
    if n == 1:
        return vals[0]
    pos = (n - 1) * q
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return vals[lo]
    return vals[lo] + (vals[hi] - vals[lo]) * (pos - lo) / (hi - lo)

print("**Table 2: Demographics of our dataset of 107 Java projects**\n")
print("|                           |    Q1 |  Q2 |   Q3 | min |     max |")
print("| ------------------------- | ----: | --: | ---: | --: | ------: |")

for label, col in cols.items():
    vals = series(col)
    q1 = quantile(vals, 0.25)
    q2 = quantile(vals, 0.5)
    q3 = quantile(vals, 0.75)
    mn = min(vals)
    mx = max(vals)

    if col == "directDepNumber":
        q1_f = f"{q1:.1f}"
        q2_f, q3_f = f"{int(round(q2))}", f"{int(round(q3))}"
        mn_f, mx_f = f"{int(mn)}", f"{int(mx)}"

    elif col == "releaseSize":
        # No commas for Q1–Q3 and min; comma for max
        q1_f = f"{int(round(q1))}"
        q2_f = f"{int(round(q2))}"
        q3_f = f"{int(round(q3))}"
        mn_f = f"{int(mn)}"
        mx_f = f"{int(round(mx)):,.0f}"

    elif col == "artifactSize":
        q1_f = f"{q1:.1f}"
        q2_f, q3_f = f"{int(round(q2))}", f"{int(round(q3))}"
        mn_f, mx_f = f"{int(mn)}", f"{int(mx)}"

    elif col == "dependencySize":
        # One decimal for Q1, plain ints for Q2–Q3 and min, comma for max
        q1_f = f"{q1:.1f}"
        q2_f = f"{int(round(q2))}"
        q3_f = f"{int(round(q3))}"
        mn_f = f"{int(mn)}"
        mx_f = f"{int(round(mx)):,.0f}"

    elif col == "versionSize":
        # Plain ints for Q1–Q3 and min, comma for max
        q1_f = f"{int(round(q1))}"
        q2_f = f"{int(round(q2))}"
        q3_f = f"{int(round(q3))}"
        mn_f = f"{int(mn)}"
        mx_f = f"{int(round(mx)):,.0f}"

    else:
        q1_f = q2_f = q3_f = mn_f = mx_f = "NA"

    print(f"| {label:<25} | {q1_f:>4} | {q2_f:>3} | {q3_f:>4} | {mn_f:>3} | {mx_f:>6} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
