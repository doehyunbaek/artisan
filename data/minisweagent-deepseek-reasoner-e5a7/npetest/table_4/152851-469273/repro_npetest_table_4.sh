#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**

| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |
| EvoSuite       | 50.7% |    68.0% |     64.7% |   47.3% | 64.0% | 56.9% |
| EvoSuite_{Def} | 48.8% |    62.7% |    83.3% |   45.3% | 60.0% | 55.7% |

EOTABLE
# Section 2: Artifact download
git clone https://github.com/kupl/NPETestArtifact.git /workspace/NPETestArtifact_repro
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/NPETestArtifact_repro
pip install pandas openpyxl 2>&1 | tail -5
python3 << 'PYEOF'
import pandas as pd
import numpy as np

# Read the sheet
df = pd.read_excel('rq2_result.xlsx', sheet_name='npedetection (2)')
df = df.rename(columns={'Unnamed: 0': 'Benchmark', 'Unnamed: 1': 'Project', 'evosuite': 'EvoSuite', 'evosuite_def': 'EvoSuite_Def'})

# Compute mean per benchmark, ignoring NaN rows
df_clean = df.dropna(subset=['Benchmark'])
grouped = df_clean.groupby('Benchmark')[['EvoSuite', 'EvoSuite_Def']].mean()

# Ensure order matches Table 4
order = ['NPEX', 'BugSwarm', 'Defects4J', 'Genesis', 'Bears']
grouped = grouped.reindex(order)

# Compute total as average across all rows (not average of averages)
total_evosuite = df_clean['EvoSuite'].mean()
total_evosuite_def = df_clean['EvoSuite_Def'].mean()

# Round to one decimal and format
grouped = grouped.round(1)
grouped.loc['Total'] = [total_evosuite, total_evosuite_def]

# Write to output file
with open('/workspace/repro.txt', 'w') as f:
    f.write("**Table 4: Bug-finding ability of EvoSuite with different settings. EvoSuite_{Def}: EvoSuite with no fine-tuned options.**\n\n")
    f.write("| Tool           |  NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |\n")
    f.write("| -------------- | ----: | -------: | --------: | ------: | ----: | ----: |\n")
    f.write(f"| EvoSuite       | {grouped.loc['NPEX', 'EvoSuite']:.1f}% |    {grouped.loc['BugSwarm', 'EvoSuite']:.1f}% |     {grouped.loc['Defects4J', 'EvoSuite']:.1f}% |   {grouped.loc['Genesis', 'EvoSuite']:.1f}% | {grouped.loc['Bears', 'EvoSuite']:.1f}% | {grouped.loc['Total', 'EvoSuite']:.1f}% |\n")
    f.write(f"| EvoSuite_{{Def}} | {grouped.loc['NPEX', 'EvoSuite_Def']:.1f}% |    {grouped.loc['BugSwarm', 'EvoSuite_Def']:.1f}% |     {grouped.loc['Defects4J', 'EvoSuite_Def']:.1f}% |   {grouped.loc['Genesis', 'EvoSuite_Def']:.1f}% | {grouped.loc['Bears', 'EvoSuite_Def']:.1f}% | {grouped.loc['Total', 'EvoSuite_Def']:.1f}% |\n")

# Also print to stdout for verification
print("Table written to /workspace/repro.txt")
PYEOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
