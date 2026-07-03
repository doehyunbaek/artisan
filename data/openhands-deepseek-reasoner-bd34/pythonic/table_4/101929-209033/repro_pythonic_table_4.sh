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
echo "Downloading artifact from Zenodo..."
curl -L -o /workspace/artifact.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content" 2>/dev/null
echo "Unzipping artifact..."
mkdir -p /workspace/artifact
unzip -q /workspace/artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running analysis via Docker (this may take a few minutes)..."
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest >/dev/null 2>&1
./run-analysis.sh >/dev/null 2>&1
echo "Extracting Table 4 results..."
# Write extraction script
cat > /workspace/extract_table.py <<'EXTRACT'
#!/usr/bin/env python3
import sys
import re
import csv

def read_diagnostics(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
    diagnostics = {}
    for i, line in enumerate(lines):
        if line.strip().startswith('AIC'):
            nums = lines[i+1].strip().split()
            diagnostics['AIC'] = float(nums[0])
            diagnostics['BIC'] = float(nums[1])
            diagnostics['logLik'] = float(nums[2])
            diagnostics['deviance'] = float(nums[3])
            diagnostics['df.residuals'] = int(nums[4])
        elif line.strip().startswith('Scaled residuals:'):
            vals = lines[i+2].strip().split()
            diagnostics['Scaled residuals'] = {
                'Min': float(vals[0]),
                '1Q': float(vals[1]),
                'Median': float(vals[2]),
                '3Q': float(vals[3]),
                'Max': float(vals[4])
            }
        elif line.strip().startswith('Random effects:'):
            var_line = lines[i+2].strip()
            parts = var_line.split()
            diagnostics['Random effects variance'] = float(parts[2])
            diagnostics['Random effects stddev'] = float(parts[3])
        elif line.strip().startswith('Number of obs:'):
            match = re.search(r'Number of obs:\s*(\d+),\s*groups:\s*\w+,\s*(\d+)', line)
            if match:
                diagnostics['Number of obs'] = int(match.group(1))
                diagnostics['Groups count'] = int(match.group(2))
    return diagnostics

def read_coefficients(filepath):
    with open(filepath, 'r') as f:
        reader = csv.reader(f)
        rows = list(reader)
    header = rows[0]
    data = rows[1:]
    coeffs = []
    for row in data:
        coeffs.append({
            'OR': float(row[0]),
            'Estimate': float(row[1]),
            'Std.Error': float(row[2]),
            'z value': float(row[3]),
            'Pr(>|z|)': float(row[4])
        })
    return coeffs

def main():
    base = '/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results'
    diag = read_diagnostics(base + '/Table-4-RQ1-comp.txt')
    coeffs = read_coefficients(base + '/Table-4-RQ1-comp-coeff.txt')
    term_names = [
        '(Intercept)',
        'MainFactorProc',
        'Compl.',
        'Usage Freq.',
        'Approvals',
        'StudentTrue',
        'MainFactorProc:Compl.'
    ]
    with open('/workspace/repro.txt', 'w') as out:
        out.write('**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**\n\n')
        out.write('|                  |        |\n')
        out.write('| ---------------- | ------ |\n')
        out.write(f'| **AIC**          | {diag["AIC"]:.1f}  |\n')
        out.write(f'| **BIC**          | {diag["BIC"]:.1f}  |\n')
        out.write(f'| **logLik**       | {diag["logLik"]:.1f} |\n')
        out.write(f'| **deviance**     | {diag["deviance"]:.1f} |\n')
        out.write(f'| **df.residuals** | {diag["df.residuals"]}    |\n\n')
        sr = diag['Scaled residuals']
        out.write(f'**Scaled residuals:** Min {sr["Min"]:.2f}, 1Q {sr["1Q"]:.2f}, Median {sr["Median"]:.2f}, 3Q {sr["3Q"]:.2f}, Max {sr["Max"]:.2f}\n\n')
        out.write(f'**Random effects (Groups)** — User (Intercept): Variance {diag["Random effects variance"]:.0f}, Std.Dev. {diag["Random effects stddev"]:.0f}; ')
        out.write(f'Number of obs: {diag["Number of obs"]}, groups: User, {diag["Groups count"]}\n\n')
        out.write('**Fixed effects**\n\n')
        out.write('| Term | OR | Estimate | Std.Error | z value | Pr(>\\|z\\|) |\n')
        out.write('|---|---:|---:|---:|---:|---:|\n')
        for i, term in enumerate(term_names):
            c = coeffs[i]
            out.write(f'| {term} | {c["OR"]:.2f} | {c["Estimate"]:.2f} | {c["Std.Error"]:.2f} | {c["z value"]:.2f} | {c["Pr(>|z|)"]:.2f} |\n')

if __name__ == '__main__':
    main()
EXTRACT
python3 /workspace/extract_table.py
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'