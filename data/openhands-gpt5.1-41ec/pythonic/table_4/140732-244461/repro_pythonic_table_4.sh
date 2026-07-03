#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 534.7  |
| **BIC**          | 566.3  |
| **logLik**       | -259.3 |
| **deviance**     | 518.7  |
| **df.residuals** | 378    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.15 | 0.14 | 0.89 | 0.16 | 0.88 |
| MainFactorProc | 6.11 | 1.81 | 0.60 | 3.00 | 0.02 |
| Compl. | 1.02 | 0.02 | 0.11 | 0.15 | 0.88 |
| Usage Freq. | 0.86 | -0.15 | 0.16 | -0.94 | 0.61 |
| Approvals | 1.00 | -0.00 | 0.00 | -1.12 | 0.61 |
| StudentTrue | 1.19 | 0.18 | 0.66 | 0.27 | 0.88 |
| MainFactorProc:Compl. | 0.65 | -0.43 | 0.17 | -2.58 | 0.03 |

EOTABLE
# Section 2: Artifact download
mkdir -p /workspace/artifact
curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip?download=1" -o /workspace/ICSE2024-funcConstructs-Artifacts.zip
unzip -q /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
sh run-analysis.sh
python - <<'EOPY'
import csv, re, pathlib
base = pathlib.Path('/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results')
summary_path = base / 'Table-4-RQ1-comp.txt'
coeff_path = base / 'Table-4-RQ1-comp-coeff.txt'
text = summary_path.read_text()
# Extract global fit statistics
m = re.search(r"AIC\s+([0-9.]+)\s+BIC\s+([0-9.]+)\s+(-?[0-9.]+)\s+([0-9.]+)\s+([0-9]+)", text)
if not m:
    raise SystemExit('Failed to parse AIC/BIC/logLik/deviance/df.resid')
AIC, BIC, logLik, deviance, df_resid = m.groups()
# Extract scaled residuals (third line after header)
lines = text.splitlines()
idx = lines.index('Scaled residuals: ')
scaled_vals = lines[idx+2].split()
min_r, q1_r, med_r, q3_r, max_r = map(float, scaled_vals)
# Extract random effects and counts
m_var = re.search(r"User\s+\(Intercept\)\s+([0-9.]+)\s+([0-9.]+)", text)
if not m_var:
    raise SystemExit('Failed to parse random-effects variance/std.dev')
var_u, sd_u = m_var.groups()
m_n = re.search(r"Number of obs:\s*([0-9]+),\s*groups:\s*User,\s*([0-9]+)", text)
if not m_n:
    raise SystemExit('Failed to parse number of obs/groups')
num_obs, num_groups = m_n.groups()
# Read coefficient table with OR and stats
rows = []
with coeff_path.open() as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        rows.append([float(x) for x in row])
terms = [
    '(Intercept)',
    'MainFactorProc',
    'Compl.',
    'Usage Freq.',
    'Approvals',
    'StudentTrue',
    'MainFactorProc:Compl.',
]
def fmt(x):
    return f"{x:.2f}"
lines_out = []
lines_out.append("**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**")
lines_out.append("")
lines_out.append("|                  |        |")
lines_out.append("| ---------------- | ------ |")
lines_out.append(f"| **AIC**          | {fmt(float(AIC))}  |")
lines_out.append(f"| **BIC**          | {fmt(float(BIC))}  |")
lines_out.append(f"| **logLik**       | {fmt(float(logLik))} |")
lines_out.append(f"| **deviance**     | {fmt(float(deviance))}  |")
lines_out.append(f"| **df.residuals** | {df_resid}    |")
lines_out.append("")
lines_out.append(
    "**Scaled residuals:** Min "
    f"{fmt(min_r)}, 1Q {fmt(q1_r)}, Median {fmt(med_r)}, "
    f"3Q {fmt(q3_r)}, Max {fmt(max_r)}"
)
lines_out.append("")
lines_out.append(
    f"**Random effects (Groups)** — User (Intercept): Variance {fmt(float(var_u))[:-3]}, "
    f"Std.Dev. {fmt(float(sd_u))[:-3]}; Number of obs: {num_obs}, groups: User, {num_groups}"
)
lines_out.append("")
lines_out.append("**Fixed effects**")
lines_out.append("")
lines_out.append("| Term | OR | Estimate | Std.Error | z value | Pr(>\\|z\\|) |")
lines_out.append("|---|---:|---:|---:|---:|---:|")
for term, (OR, est, se, z, p) in zip(terms, rows):
    lines_out.append(
        f"| {term} | {fmt(OR)} | {fmt(est)} | {fmt(se)} | {fmt(z)} | {fmt(p)} |"
    )
pathlib.Path('/workspace/repro.txt').write_text("\n".join(lines_out) + "\n")
EOPY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
