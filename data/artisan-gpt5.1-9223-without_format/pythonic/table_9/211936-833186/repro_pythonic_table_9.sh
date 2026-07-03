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
python3 - <<'PY'
import csv, pathlib

workspace = pathlib.Path("/workspace")
artifact = pathlib.Path(".")

# Compute sample sizes with the same filters used in the R script
rq2_path = artifact / "working-results" / "RQ1-RQ2-files-for-statistical-analysis" / "RQ1Paired-RQ2.csv"
n_lambda = n_comp = n_mrf = 0

with rq2_path.open(newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Lambda
        try:
            lu = float(row["LambdaUsageFrequency"])
        except (KeyError, ValueError, TypeError):
            lu = None
        if lu is not None and lu > 1 and row.get("LambdaComparisonAssessment") not in ("extreme_chatgpt", "no"):
            n_lambda += 1
        # Comprehension
        try:
            cu = float(row["CompUsageFrequency"])
        except (KeyError, ValueError, TypeError):
            cu = None
        if cu is not None and cu > 1 and row.get("CompComparisonAssessment") not in ("extreme_chatgpt", "no"):
            n_comp += 1
        # MRF
        try:
            mu = float(row["MrfUsageFrequency"])
        except (KeyError, ValueError, TypeError):
            mu = None
        if mu is not None and mu > 1 and row.get("MrfComparisonAssessment") not in ("extreme_chatgpt", "no"):
            n_mrf += 1

def read_two_row_table(path):
    with path.open(newline='') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    out = []
    for row in rows[:2]:
        OR = float(row["OR"])
        est = float(row["Value"])
        se = float(row["Std. Error"])
        tval = float(row["t value"])
        pval = float(row["p value"])
        out.append((OR, est, se, tval, pval))
    return out

lambda_tab = read_two_row_table(artifact / "results" / "Table-9-rq2-lambda.csv")
comp_tab = read_two_row_table(artifact / "results" / "Table-9-rq2-comp.csv")

# Read MRF table (single column with header 'x')
mrf_csv = artifact / "results" / "Table-9-rq2-mrf.csv"
vals = []
with mrf_csv.open() as f:
    for line in f:
        line = line.strip()
        if not line or line == "x":
            continue
        vals.append(float(line))
if len(vals) != 5:
    raise SystemExit(f"Unexpected number of values in {mrf_csv}: {len(vals)}")
or_mrf, est_mrf, se_mrf, t_mrf, p_mrf = vals

def fmt(x):
    return f"{x:.2f}"

lines = []
lines.append("**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**\n")
lines.append("\n")
lines.append(f"**Lambda ({n_lambda} data points)**\n")
lines.append("\n")
lines.append("| Term        |   OR | Estimate | StdError | t-value | p-value |\n")
lines.append("| ----------- | ---: | -------: | -------: | ------: | ------: |\n")
OR, est, se, tval, pval = lambda_tab[0]
lines.append(f"| Usage Freq. | {fmt(OR)} |     {fmt(est)} |     {fmt(se)} |    {fmt(tval)} |    {fmt(pval)} |\n")
OR, est, se, tval, pval = lambda_tab[1]
lines.append(f"| Compl.      | {fmt(OR)} |    {fmt(est)} |     {fmt(se)} |   {fmt(tval)} |    {fmt(pval)} |\n")
lines.append("\n")
lines.append(f"**Comprehension ({n_comp} data points)**\n")
lines.append("\n")
lines.append("| Term        |   OR | Estimate | StdError | t-value | p-value |\n")
lines.append("| ----------- | ---: | -------: | -------: | ------: | ------: |\n")
OR, est, se, tval, pval = comp_tab[0]
lines.append(f"| Usage Freq. | {fmt(OR)} |     {fmt(est)} |     {fmt(se)} |    {fmt(tval)} |    {fmt(pval)} |\n")
OR, est, se, tval, pval = comp_tab[1]
lines.append(f"| Compl.      | {fmt(OR)} |    {fmt(est)} |     {fmt(se)} |   {fmt(tval)} |    {fmt(pval)} |\n")
lines.append("\n")
lines.append(f"**MRF ({n_mrf} data points)**\n")
lines.append("\n")
lines.append("| Term        |   OR | Estimate | StdError | t-value | p-value |\n")
lines.append("| ----------- | ---: | -------: | -------: | ------: | ------: |\n")
lines.append(f"| Usage Freq. | {fmt(or_mrf)} |     {fmt(est_mrf)} |     {fmt(se_mrf)} |    {fmt(t_mrf)} |    {fmt(p_mrf)} |\n")
lines.append("\n")

out_path = workspace / "repro.txt"
out_path.write_text("".join(lines))
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
