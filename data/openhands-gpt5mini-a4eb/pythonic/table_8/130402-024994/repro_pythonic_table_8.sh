#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -15.80 | 1383.44 | 0.01 | 0.99 |
| MainFactorProc | -0.06 | 0.40 | -0.16 | 0.99 |
| Usage Freq. | -0.18 | 0.33 | -0.54 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.76 | 0.99 |
| StudentTrue | 15.56 | 1383.44 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
# Download replication package from Zenodo
curl -sL "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content" -o /workspace/ICSE2024-funcConstructs-Artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract the needed CSV
unzip -p /workspace/ICSE2024-funcConstructs-Artifacts.zip ICSE2024-funcConstructs-Artifacts/working-results/RQ1-RQ2-files-for-statistical-analysis/RQ1.csv > /workspace/RQ1.csv

# Install python dependencies
python3 -m pip install --user statsmodels pandas scipy patsy >/dev/null 2>&1 || true

# Run the reproduction (compute logistic regression on filter subset)
python3 - << 'PY'
import pandas as pd
import statsmodels.api as sm
from statsmodels.stats.multitest import multipletests

# Load data
df = pd.read_csv('/workspace/RQ1.csv')
# Filter: Section==mrf, Construct==filter, UsageFrequency>1
t = df[(df['Section']=='mrf') & (df['Construct']=='filter') & (df['UsageFrequency']>1)].copy()
# Map Outcome to 0/1
t['Outcome'] = t['Outcome'].map({'TRUE':1,'FALSE':0, True:1, False:0})
# Create dummy for MainFactor: reference is 'f', so create indicator for 'p'
t['MainFactorp'] = (t['MainFactor']=='p').astype(int)
# Student True dummy
t['StudentTrue'] = ((t['Student']==True) | (t['Student']=='TRUE') | (t['Student']=='True')).astype(int)
# Ensure numeric columns
for col in ['UsageFrequency','Approvals']:
    t[col] = pd.to_numeric(t[col], errors='coerce')

# Drop rows with NaNs in predictors or outcome
t = t.dropna(subset=['Outcome','MainFactorp','UsageFrequency','Approvals','StudentTrue'])

# Prepare design matrix
X = t[['MainFactorp','UsageFrequency','Approvals','StudentTrue']]
X = sm.add_constant(X)
X = X.astype(float)
Y = t['Outcome'].astype(float)

model = sm.GLM(Y, X, family=sm.families.Binomial()).fit()
# Get coefficients
params = model.params
bse = model.bse
z = params / bse
pvals = model.pvalues
# Adjust p-values BH
adj = multipletests(pvals, method='fdr_bh')[1]
# Prepare table similar to R's mc
mc = pd.DataFrame({
    'Estimate': params,
    'Std.Error': bse,
    'z value': z,
    'Pr(>|z|)': adj
})
# Write outputs
mc.to_csv('/workspace/Table-8-RQ1-filter.csv')
with open('/workspace/repro.txt','w') as f:
    f.write('AIC=' + str(round(model.aic)) + '\n\n')
    f.write(mc.to_csv())

print('Reproduction complete. Results written to /workspace/repro.txt')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'
