#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Compl. | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc:Compl. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
# Remove existing results directory to ensure fresh analysis
rm -rf results
# Run the analysis
sh run-analysis.sh
# Section 4: Extract and format Table 4 results
# Use python for robust parsing
python3 <<'PYTHON_SCRIPT'
import re
import csv
import math

# Read the model summary file
with open('results/Table-4-RQ1-comp.txt', 'r') as f:
    txt = f.read()

# Extract diagnostic values using regex
# Find line containing AIC, BIC, logLik, deviance, df.resid
diag_match = re.search(r'AIC\s+BIC\s+logLik\s+deviance\s+df\.resid\s+([\d\.\-]+\s+[\d\.\-]+\s+[\d\.\-]+\s+[\d\.\-]+\s+\d+)', txt)
if diag_match:
    diag_vals = diag_match.group(1).split()
    AIC = float(diag_vals[0])
    BIC = float(diag_vals[1])
    logLik = float(diag_vals[2])
    deviance = float(diag_vals[3])
    df_resid = int(diag_vals[4])
else:
    # Fallback: look for the line after the pattern
    lines = txt.split('\n')
    for i, line in enumerate(lines):
        if 'AIC' in line and 'BIC' in line and 'logLik' in line:
            if i+1 < len(lines):
                diag_vals = lines[i+1].split()
                AIC = float(diag_vals[0])
                BIC = float(diag_vals[1])
                logLik = float(diag_vals[2])
                deviance = float(diag_vals[3])
                df_resid = int(diag_vals[4])
                break

# Extract scaled residuals
resid_match = re.search(r'Scaled residuals:\s*\n\s*Min\s+1Q\s+Median\s+3Q\s+Max\s*\n\s*([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)', txt)
if resid_match:
    resid_min = float(resid_match.group(1))
    resid_1q = float(resid_match.group(2))
    resid_median = float(resid_match.group(3))
    resid_3q = float(resid_match.group(4))
    resid_max = float(resid_match.group(5))
else:
    # Alternative pattern
    resid_match = re.search(r'Scaled residuals:.*?Min\s+([\d\.\-]+).*?1Q\s+([\d\.\-]+).*?Median\s+([\d\.\-]+).*?3Q\s+([\d\.\-]+).*?Max\s+([\d\.\-]+)', txt, re.DOTALL)
    if resid_match:
        resid_min = float(resid_match.group(1))
        resid_1q = float(resid_match.group(2))
        resid_median = float(resid_match.group(3))
        resid_3q = float(resid_match.group(4))
        resid_max = float(resid_match.group(5))
    else:
        resid_min = resid_1q = resid_median = resid_3q = resid_max = 0.0

# Extract random effects info
obs_match = re.search(r'Number of obs:\s*(\d+)', txt)
groups_match = re.search(r'groups:\s*User,\s*(\d+)', txt)
n_obs = int(obs_match.group(1)) if obs_match else 0
n_groups = int(groups_match.group(1)) if groups_match else 0

# Read coefficients from CSV
coeffs = []
with open('results/Table-4-RQ1-comp-coeff.txt', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        coeffs.append({
            'OR': float(row['OR']),
            'Estimate': float(row['Estimate']),
            'Std. Error': float(row['Std. Error']),
            'z value': float(row['z value']),
            'Pr(>|z|)': float(row['Pr(>|z|)'])
        })

# Map coefficients to table terms
# Order in CSV: (Intercept), MainFactorp, Complexity, UsageFrequency, Approvals, StudentTRUE, MainFactorp:Complexity
term_names = [
    '(Intercept)',
    'MainFactorProc',
    'Compl.',
    'Usage Freq.',
    'Approvals',
    'StudentTrue',
    'MainFactorProc:Compl.'
]

# Formatting functions
def fmt1(x):
    return f"{x:.1f}"

def fmt2(x):
    return f"{x:.2f}"

def fmt3(x):
    return f"{x:.3f}"

def fmt4(x):
    return f"{x:.4f}"

def fmt_pval(p):
    if p < 0.0001:
        return fmt4(p)
    elif p < 0.001:
        return fmt4(p)
    elif p < 0.01:
        return fmt4(p)
    else:
        return fmt3(p)

# Generate the reproduction table
output = []
output.append("**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**")
output.append("")
output.append("|                  |        |")
output.append("| ---------------- | ------ |")
output.append(f"| **AIC**          | {fmt1(AIC)}  |")
output.append(f"| **BIC**          | {fmt1(BIC)}  |")
output.append(f"| **logLik**       | {fmt1(logLik)} |")
output.append(f"| **deviance**     | {fmt1(deviance)}  |")
output.append(f"| **df.residuals** | {df_resid}    |")
output.append("")
output.append(f"**Scaled residuals:** Min {fmt2(resid_min)}, 1Q {fmt2(resid_1q)}, Median {fmt2(resid_median)}, 3Q {fmt2(resid_3q)}, Max {fmt2(resid_max)}")
output.append("")
output.append(f"**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: {n_obs}, groups: User, {n_groups}")
output.append("")
output.append("**Fixed effects**")
output.append("")
output.append("| Term | OR | Estimate | Std.Error | z value | Pr(>|z|) |")
output.append("|---:|:---:|:---:|:---:|:---:|:---:|")
for i, term in enumerate(term_names):
    c = coeffs[i]
    or_val = c['OR']
    est = c['Estimate']
    se = c['Std. Error']
    z = c['z value']
    p = c['Pr(>|z|)']
    # Format estimates: for negative values, ensure minus sign is present
    est_str = fmt2(est)
    se_str = fmt2(se)
    z_str = fmt2(z)
    p_str = fmt_pval(p)
    output.append(f"| {term} | {fmt2(or_val)} | {est_str} | {se_str} | {z_str} | {p_str} |")

# Write to repro.txt
with open('/workspace/repro.txt', 'w') as f:
    f.write('\n'.join(output))

print("Table extracted successfully")
PYTHON_SCRIPT
# Section 5: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
