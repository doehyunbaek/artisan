#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 2.29 |     0.83 |     0.31 |    2.65 |    0.02 |
| Compl.      | 0.88 |    -0.13 |     0.18 |   -0.73 |    0.47 |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 1.49 |     0.40 |     0.22 |    1.84 |    0.07 |
| Compl.      | 0.77 |    -0.26 |     0.11 |   -2.27 |    0.05 |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 1.79 |     0.58 |     0.25 |    2.31 |    0.02 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip -o ICSE2024-funcConstructs-Artifacts.zip
rm -rf ICSE2024-funcConstructs-Artifacts
unzip -o ICSE2024-funcConstructs-Artifacts.zip -d ICSE2024-funcConstructs-Artifacts
# Section 3: Reproduction commands (populate from reviewed steps)
docker pull mdipenta/rexp:latest
ARTIFACT_DIR="/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts"
cd "$ARTIFACT_DIR"
sh run-analysis.sh
python - <<'PY'
import csv
from pathlib import Path

artifact_root = Path("/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts")
results_dir = artifact_root / "results"
out_path = Path("/workspace/repro.txt")


def fmt(x: str) -> str:
    return f"{float(x):.2f}"


# Lambda
with (results_dir / "Table-9-rq2-lambda.csv").open() as f:
    lam_rows = list(csv.DictReader(f))

# Comprehension
with (results_dir / "Table-9-rq2-comp.csv").open() as f:
    comp_rows = list(csv.DictReader(f))

# MRF (simple CSV-like with single column)
mrf_file = results_dir / "Table-9-rq2-mrf.csv"
with mrf_file.open() as f:
    vals = [line.strip() for line in f if line.strip()]

# First line is header; remaining five lines are OR, Estimate, StdError, t-value, p-value
num_vals = [float(v) for v in vals[1:6]]
or_mrf, est_mrf, se_mrf, t_mrf, p_mrf = num_vals

lines = []
lines.append("**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**")
lines.append("")

lines.append("**Lambda (90 data points)**")
lines.append("")
lines.append("| Term        |   OR | Estimate | StdError | t-value | p-value |")
lines.append("| ----------- | ---: | -------: | -------: | ------: | ------: |")
lam_usage = lam_rows[0]
lam_cplx = lam_rows[1]
lines.append(f"| Usage Freq. | {fmt(lam_usage['OR'])} |     {fmt(lam_usage['Value'])} |     {fmt(lam_usage['Std. Error'])} |    {fmt(lam_usage['t value'])} |    {fmt(lam_usage['p value'])} |")
lines.append(f"| Compl.      | {fmt(lam_cplx['OR'])} |    {fmt(lam_cplx['Value'])} |     {fmt(lam_cplx['Std. Error'])} |   {fmt(lam_cplx['t value'])} |    {fmt(lam_cplx['p value'])} |")
lines.append("")

lines.append("**Comprehension (120 data points)**")
lines.append("")
lines.append("| Term        |   OR | Estimate | StdError | t-value | p-value |")
lines.append("| ----------- | ---: | -------: | -------: | ------: | ------: |")
comp_usage = comp_rows[0]
comp_cplx = comp_rows[1]
lines.append(f"| Usage Freq. | {fmt(comp_usage['OR'])} |     {fmt(comp_usage['Value'])} |     {fmt(comp_usage['Std. Error'])} |    {fmt(comp_usage['t value'])} |    {fmt(comp_usage['p value'])} |")
lines.append(f"| Compl.      | {fmt(comp_cplx['OR'])} |    {fmt(comp_cplx['Value'])} |     {fmt(comp_cplx['Std. Error'])} |   {fmt(comp_cplx['t value'])} |    {fmt(comp_cplx['p value'])} |")
lines.append("")

lines.append("**MRF (103 data points)**")
lines.append("")
lines.append("| Term        |   OR | Estimate | StdError | t-value | p-value |")
lines.append("| ----------- | ---: | -------: | -------: | ------: | ------: |")
lines.append(f"| Usage Freq. | {fmt(or_mrf)} |     {fmt(est_mrf)} |     {fmt(se_mrf)} |    {fmt(t_mrf)} |    {fmt(p_mrf)} |")

out_path.write_text("\n".join(lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
