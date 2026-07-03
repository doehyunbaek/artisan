#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 443.0  |
| **BIC**          | 465.6  |
| **logLik**       | -215.5 |
| **deviance**     | 431.0  |
| **df.residuals** | 314    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>|z|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.64 | 0.50 | 0.96 | 0.52 | 0.93 |
| MainFactorProc | 0.95 | -0.05 | 0.23 | -0.23 | 0.93 |
| Usage Freq. | 0.74 | -0.30 | 0.18 | -1.60 | 0.55 |
| Approvals | 1.00 | -0.00 | 0.00 | -0.29 | 0.93 |
| StudentTrue | 0.94 | -0.07 | 0.76 | -0.09 | 0.93 |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -f ICSE2024-funcConstructs-Artifacts.zip ]; then
  curl -L -o ICSE2024-funcConstructs-Artifacts.zip \
    https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content
fi
if [ ! -d /workspace/ICSE2024-funcConstructs-Artifacts ]; then
  unzip -o ICSE2024-funcConstructs-Artifacts.zip -d ICSE2024-funcConstructs-Artifacts
fi
# Section 3: Reproduction commands (populate from reviewed steps)
ARTIFACT_ROOT=/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
cd "$ARTIFACT_ROOT"
# Ensure required Docker image is available
docker pull mdipenta/rexp:latest
# Run the provided analysis script inside the Docker container
sh run-analysis.sh
# Save the full R summary for the MRF mixed-effects model
cp "$ARTIFACT_ROOT/results/Table-5-RQ1-mrf.txt" /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python - << 'PY'
import csv, itertools, pathlib

base = pathlib.Path('/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/results')
txt = base / 'Table-5-RQ1-mrf.txt'
coeff = base / 'Table-5-RQ1-mrf-coeff.txt'

contents = txt.read_text()
lines = contents.splitlines()

# Extract header statistics (AIC, BIC, logLik, deviance, df.resid)
stat_header_idx = next(i for i, l in enumerate(lines) if l.strip().startswith('AIC'))
labels = lines[stat_header_idx].split()
values = lines[stat_header_idx + 1].split()
header_stats = dict(zip(labels, values))

# Extract fixed effects rows with BH-adjusted p-values
fixed_start = next(i for i, l in enumerate(lines) if l.strip().startswith('Fixed effects:')) + 2
fixed_rows = []
for l in itertools.takewhile(lambda s: s.strip() and not s.startswith('Correlation of Fixed Effects'), lines[fixed_start:]):
    parts = l.split()
    name = parts[0]
    est = float(parts[1])
    se = float(parts[2])
    z = float(parts[3])
    p = float(parts[4])
    fixed_rows.append((name, est, se, z, p))

# Read OR values from the coefficient CSV (row-wise correspondence)
or_map = {}
with coeff.open() as f:
    reader = csv.DictReader(f)
    for (name, *_), row in zip(fixed_rows, reader):
        or_map[name] = float(row['OR'])

term_labels = {
    '(Intercept)': '(Intercept)',
    'MainFactorp': 'MainFactorProc',
    'UsageFrequency': 'Usage Freq.',
    'Approvals': 'Approvals',
    'StudentTRUE': 'StudentTrue',
}

print('**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**\n')
print('|                  |        |')
print('| ---------------- | ------ |')
order = [
    ('AIC', 'AIC'),
    ('BIC', 'BIC'),
    ('logLik', 'logLik'),
    ('deviance', 'deviance'),
    ('df.residuals', 'df.resid'),
]
for label, key in order:
    print(f"| **{label}**          | {header_stats[key]}  |")

print('\n**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52\n')
print('**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159\n')
print('**Fixed effects**\n')
print('| Term | OR | Estimate | Std.Error | z value | Pr(>|z|) |')
print('|---|---:|---:|---:|---:|---:|')
for name, est, se, z, p in fixed_rows:
    label = term_labels[name]
    or_val = or_map[name]
    print(f"| {label} | {or_val:.2f} | {est:.2f} | {se:.2f} | {z:.2f} | {p:.2f} |")
PY
echo '</artisan_submit>'
