#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -13.20 | 1696.36 | -0.01 | 0.99 |
| MainFactorProc | -0.26 | 0.47 | -0.56 | 0.99 |
| Usage Freq. | -0.83 | 0.44 | -1.87 | 0.30 |
| Approvals | 0.00 | 0.00 | -0.36 | 0.99 |
| StudentTrue | 14.38 | 1696.36 | 0.01 | 0.99 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact..."
curl -L -o /workspace/artifact.zip "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content"
mkdir -p /workspace/artifact
unzip -q /workspace/artifact.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running reproduction analysis..."
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
# Ensure Docker image is available
docker pull mdipenta/rexp > /dev/null 2>&1
# Run the analysis script
sh run-analysis.sh 2>&1 | tee /workspace/repro.log
# Extract the generated table
cp results/Table-7-RQ1-reduce.csv /workspace/table7.csv

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the table as markdown
python3 <<'EOF'
import pandas as pd
import sys
df = pd.read_csv('/workspace/table7.csv')
# Assign term names
terms = ['(Intercept)', 'MainFactorProc', 'Usage Freq.', 'Approvals', 'StudentTrue']
# Round values
def round_val(x):
    return round(x, 2)
df['Estimate'] = df['Estimate'].apply(round_val)
df['Std. Error'] = df['Std. Error'].apply(round_val)
df['z value'] = df['z value'].apply(round_val)
df['Pr(>|z|)'] = df['Pr(>|z|)'].apply(lambda x: round(x, 2))
# Build markdown table
print("**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**")
print()
print("| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |")
print("|---|---:|---:|---:|---:|")
for i, row in df.iterrows():
    term = terms[i]
    est = row['Estimate']
    se = row['Std. Error']
    z = row['z value']
    p = row['Pr(>|z|)']
    print(f"| {term} | {est:.2f} | {se:.2f} | {z:.2f} | {p:.2f} |")
EOF
echo '</artisan_submit>'