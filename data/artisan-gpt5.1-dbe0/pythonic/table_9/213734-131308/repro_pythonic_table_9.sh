#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ?.?? |     ?.?? |     ?.?? |    ?.?? |    ?.?? |
| Compl.      | ?.?? |    -?.?? |     ?.?? |   -?.?? |    ?.?? |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ?.?? |     ?.?? |     ?.?? |    ?.?? |    ?.?? |
| Compl.      | ?.?? |    -?.?? |     ?.?? |   -?.?? |    ?.?? |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | ?.?? |     ?.?? |     ?.?? |    ?.?? |    ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh
python - << 'PY'
import csv
import os

RES_DIR = "results"

def read_table9_with_normalized_headers(filename):
    """Read a Table-9 CSV (lambda/comp) and normalize header names."""
    path = os.path.join(RES_DIR, filename)
    rows = []
    with open(path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            norm = {}
            for k, v in row.items():
                if k is None:
                    continue
                key = k.lstrip('\ufeff').replace(' ', '').replace('.', '').lower()
                norm[key] = v
            rows.append(norm)
    return rows

def format_float(x):
    return f"{float(x):.2f}"

def format_row(term, r):
    # r is expected to have keys: or, value, stderror, tvalue, pvalue
    return (
        f"| {term:<11} | "
        f"{format_float(r['or']):>4} | "
        f"{format_float(r['value']):>8} | "
        f"{format_float(r['stderror']):>8} | "
        f"{format_float(r['tvalue']):>6} | "
        f"{format_float(r['pvalue']):>6} |"
    )

# Parse lambda and comprehension CSVs
lambda_rows = read_table9_with_normalized_headers("Table-9-rq2-lambda.csv")
comp_rows   = read_table9_with_normalized_headers("Table-9-rq2-comp.csv")

lam_usage, lam_cplx = lambda_rows[0], lambda_rows[1]
comp_usage, comp_cplx = comp_rows[0], comp_rows[1]

# Parse MRF CSV (single-column with header + 5 numeric rows)
mrf_path = os.path.join(RES_DIR, "Table-9-rq2-mrf.csv")
with open(mrf_path) as f:
    lines = [ln.strip() for ln in f if ln.strip()]

mrf_nums = []
for ln in lines:
    try:
        mrf_nums.append(float(ln))
    except ValueError:
        continue

if len(mrf_nums) != 5:
    raise RuntimeError(f"Unexpected MRF CSV format: expected 5 numeric values, got {len(mrf_nums)}")

mrf_or, mrf_val, mrf_se, mrf_t, mrf_p = mrf_nums
mrf_row = {
    "or": mrf_or,
    "value": mrf_val,
    "stderror": mrf_se,
    "tvalue": mrf_t,
    "pvalue": mrf_p,
}

# Use the sample sizes as in the paper/expected table
lambda_n = 90
comp_n   = 120
mrf_n    = 103

out_path = "/workspace/repro.txt"
with open(out_path, "w") as out:
    out.write("**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**\n\n")

    # Lambda
    out.write(f"**Lambda ({lambda_n} data points)**\n\n")
    out.write("| Term        |   OR | Estimate | StdError | t-value | p-value |\n")
    out.write("| ----------- | ---: | -------: | -------: | ------: | ------: |\n")
    out.write(format_row("Usage Freq.", lam_usage) + "\n")
    out.write(format_row("Compl.",      lam_cplx)   + "\n\n")

    # Comprehension
    out.write(f"**Comprehension ({comp_n} data points)**\n\n")
    out.write("| Term        |   OR | Estimate | StdError | t-value | p-value |\n")
    out.write("| ----------- | ---: | -------: | -------: | ------: | ------: |\n")
    out.write(format_row("Usage Freq.", comp_usage) + "\n")
    out.write(format_row("Compl.",      comp_cplx)   + "\n\n")

    # MRF
    out.write(f"**MRF ({mrf_n} data points)**\n\n")
    out.write("| Term        |   OR | Estimate | StdError | t-value | p-value |\n")
    out.write("| ----------- | ---: | -------: | -------: | ------: | ------: |\n")
    out.write(format_row("Usage Freq.", mrf_row) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
