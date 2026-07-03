#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**

| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |
| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----: |
| 5 min  | EvoSuite |   ?? |       ?? |         ? |       ? |     ? |    ?? |
|        | NPETest  |   ?? |       ?? |         ? |       ? |     ? |    ?? |
EOTABLE
# Section 2: Artifact download
artisan get https://github.com/kupl/NPETestArtifact
# Section 3: Reproduction commands
cd /workspace/NPETestArtifact
pip install pandas openpyxl > /dev/null 2>&1
python3 << 'END' > /workspace/repro.txt
import pandas as pd
import sys

# Read the Excel file
df = pd.read_excel('rq1_result.xlsx', header=0)

# Rename the first column to 'Benchmark'
df = df.rename(columns={df.columns[0]: 'Benchmark'})

# Filter out rows where Benchmark is NaN or empty
df = df.dropna(subset=['Benchmark'])
df['Benchmark'] = df['Benchmark'].astype(str)

# We only need rows for benchmark categories: NPEX, BugSwarm, Defects4J, Genesis, Bears
valid_benchmarks = ['NPEX', 'BugSwarm', 'Defects4J', 'Genesis', 'Bears']
df = df[df['Benchmark'].isin(valid_benchmarks)]

# For evosuite and npetest, count number of projects where value > 0
evosuite_counts = {}
npetest_counts = {}

for benchmark in valid_benchmarks:
    subset = df[df['Benchmark'] == benchmark]
    evosuite_counts[benchmark] = (subset['evosuite'] > 0).sum()
    npetest_counts[benchmark] = (subset['npetest'] > 0).sum()

# Compute totals
evosuite_total = sum(evosuite_counts.values())
npetest_total = sum(npetest_counts.values())

# Output the table
print("**Table 3: The number of unique NPEs detected by each unit test generation tool with different time budgets.**")
print()
print("| Time   | Tools    | NPEX | BugSwarm | Defects4J | Genesis | Bears | Total |")
print("| ------ | -------- | ---: | -------: | --------: | ------: | ----: | ----:|")
print(f"| 5 min  | EvoSuite |   {evosuite_counts.get('NPEX', 0)} |       {evosuite_counts.get('BugSwarm', 0)} |         {evosuite_counts.get('Defects4J', 0)} |       {evosuite_counts.get('Genesis', 0)} |     {evosuite_counts.get('Bears', 0)} |    {evosuite_total} |")
print(f"|        | NPETest  |   {npetest_counts.get('NPEX', 0)} |       {npetest_counts.get('BugSwarm', 0)} |         {npetest_counts.get('Defects4J', 0)} |       {npetest_counts.get('Genesis', 0)} |     {npetest_counts.get('Bears', 0)} |    {npetest_total} |")
END
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
