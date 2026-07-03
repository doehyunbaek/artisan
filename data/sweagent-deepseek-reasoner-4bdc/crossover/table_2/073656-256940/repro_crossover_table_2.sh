#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**

| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |
| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |
| Ant     |     0.561 |     0.923 |        0.459 |        0.124 |        0.493 |        0.069 |
| BCEL    |     0.283 |     0.512 |        0.660 |        0.347 |        0.756 |        0.286 |
| Closure |     0.742 |     0.717 |        0.661 |        0.101 |        0.712 |        0.094 |
| Maven   |     0.446 |     0.589 |        0.404 |        0.497 |        0.399 |        0.453 |
| Nashorn |     0.622 |     0.646 |        0.548 |        0.117 |        0.591 |        0.132 |
| Rhino   |     0.611 |     0.502 |        0.599 |        0.263 |        0.643 |        0.255 |
| Tomcat  |     0.322 |     0.775 |        0.350 |        0.276 |        0.328 |        0.279 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact data..."
curl -L "https://ndownloader.figshare.com/files/41569575" -o /workspace/heritability.csv 2>/dev/null
# Also download the Zeugma repository
curl -L "https://ndownloader.figshare.com/files/43892865" -o /workspace/zeugma-main.zip 2>/dev/null
# Section 3: Reproduction commands
cd /workspace
echo "Extracting Zeugma repository..."
unzip -q zeugma-main.zip 2>/dev/null
echo "Computing heritability table from data..."
cat > /workspace/compute_table.py <<'PYEOF'
import pandas as pd
import numpy as np
from collections import defaultdict
import statistics

def main():
    data = pd.read_csv('/workspace/heritability.csv')
    # Compute table
    results = defaultdict(dict)
    for subject in data['subject'].unique():
        for crossover in ['Linked', 'One Point', 'Two Point']:
            subset = data[(data['subject'] == subject) & (data['crossover_operator'] == crossover)]
            if len(subset) == 0:
                continue
            hy = subset['hybrid'].mean()
            ir = subset['inheritance_rate'].median()
            results[subject][crossover] = {'HY': hy, 'IR': ir}
    # Format as table
    subjects = ['Ant', 'Bcel', 'Closure', 'Maven', 'Nashorn', 'Rhino', 'Tomcat']
    # Map Bcel to BCEL for expected table
    subject_map = {'Ant': 'Ant', 'Bcel': 'BCEL', 'Closure': 'Closure', 'Maven': 'Maven', 
                   'Nashorn': 'Nashorn', 'Rhino': 'Rhino', 'Tomcat': 'Tomcat'}
    with open('/workspace/repro.txt', 'w') as f:
        f.write('**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**\n\n')
        f.write('| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |\n')
        f.write('| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |\n')
        for subject in subjects:
            mapped = subject_map[subject]
            f.write(f'| {mapped:<7} |')
            for crossover in ['Linked', 'One Point', 'Two Point']:
                hy = results[subject][crossover]['HY']
                ir = results[subject][crossover]['IR']
                f.write(f'     {hy:.3f} |')
                f.write(f'     {ir:.3f} |')
            f.write('\n')
    # Also print to stdout for artisan
    print('<artisan_submit>')
    with open('/workspace/repro.txt', 'r') as f:
        print(f.read())
    print('</artisan_submit>')

if __name__ == '__main__':
    main()
PYEOF
python3 /workspace/compute_table.py
