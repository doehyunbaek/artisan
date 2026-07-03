#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | 16.48 | 1370.51 | 0.01 | 0.99 |
| MainFactorProc | 0.67 | 0.48 | 1.39 | 0.82 |
| Usage Freq. | -0.03 | 0.38 | -0.09 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.07 | 0.99 |
| StudentTrue | -15.75 | 1370.51 | -0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
echo "Downloading artifact from Zenodo..."
curl -s -H "Accept: application/json" "https://zenodo.org/api/records/10554377" | jq -r '.files[].links.self' | grep -v null | xargs curl -L -o /tmp/artifact.zip
# Alternative direct download
# curl -L "https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content" -o /tmp/artifact.zip
unzip -q /tmp/artifact.zip -d /tmp/artifact
cd /tmp/artifact/ICSE2024-funcConstructs-Artifacts

# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running analysis using Docker..."
docker pull mdipenta/rexp:latest > /dev/null 2>&1
cat FuncConstructs-Statistics.r | docker run --workdir /data -v${PWD}:/data --rm -i mdipenta/rexp R --no-save > /tmp/analysis.log 2>&1

# Copy results to workspace
cp results/Table-6-RQ1-map.csv /workspace/repro.csv 2>/dev/null || cp results/Table-6-RQ1-map.csv /workspace/repro.csv
cp results/Table-6-RQ1-map.tex /workspace/repro.tex 2>/dev/null || cp results/Table-6-RQ1-map.tex /workspace/repro.tex

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 << 'EOF'
import pandas as pd
import re
import sys

# Read CSV
df = pd.read_csv('/workspace/repro.csv')
# Map rows to term names
term_names = ['(Intercept)', 'MainFactorProc', 'Usage Freq.', 'Approvals', 'StudentTrue']
# Ensure we have exactly 5 rows
if len(df) != 5:
    # maybe rows are different order; try to infer from column names? Not present.
    # We'll assume order as in CSV
    pass
df['Term'] = term_names
# Round numbers
df['Estimate'] = df['Estimate'].round(2)
df['Std. Error'] = df['Std. Error'].round(2)
df['z value'] = df['z value'].round(2)
df['Pr(>|z|)'] = df['Pr(>|z|)'].round(2)
# Extract AIC from .tex file
with open('/workspace/repro.tex', 'r') as f:
    tex = f.read()
match = re.search(r'AIC=(\d+)', tex)
aic = match.group(1) if match else '?'
# Print markdown table
print(f'**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC={aic})**')
print()
print('| Term | Estimate | Std.Error | z value | Pr(>|z|) |')
print('|---:|---:|---:|---:|---:|')
for _, row in df.iterrows():
    print(f'| {row["Term"]} | {row["Estimate"]:.2f} | {row["Std. Error"]:.2f} | {row["z value"]:.2f} | {row["Pr(>|z|)"]:.2f} |')
EOF
echo '</artisan_submit>'