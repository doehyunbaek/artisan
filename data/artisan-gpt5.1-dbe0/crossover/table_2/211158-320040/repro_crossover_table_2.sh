#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**

| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |
| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |
| Ant     |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| BCEL    |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Closure |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Maven   |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Nashorn |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Rhino   |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Tomcat  |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |

EOTABLE

# Section 2: Artifact download
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Section 3: Reproduction commands (populate from reviewed steps)
# Use heritability.csv (already downloaded by artisan get) to compute Table 2 metrics.
python - <<'PY' > /workspace/repro.txt
import csv
from statistics import median
from collections import defaultdict

# Load data from heritability.csv in the current working directory
rows = []
with open('heritability.csv', newline='') as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append({
            'subject': r['subject'],
            'crossover_operator': r['crossover_operator'],
            'inheritance_rate': float(r['inheritance_rate']),
            'hybrid': r['hybrid'].strip().lower() == 'true',
        })

# Mapping from CSV subject names to display labels used in the paper/table
subjects = [
    ('Ant', 'Ant'),
    ('Bcel', 'BCEL'),
    ('Closure', 'Closure'),
    ('Maven', 'Maven'),
    ('Nashorn', 'Nashorn'),
    ('Rhino', 'Rhino'),
    ('Tomcat', 'Tomcat'),
]

# Group data by (subject, crossover_operator)
groups = defaultdict(list)
for r in rows:
    key = (r['subject'], r['crossover_operator'])
    groups[key].append(r)

def stat_inheritance(subj_csv, op):
    vals = [r['inheritance_rate'] for r in groups.get((subj_csv, op), [])]
    return median(vals) if vals else None

def stat_hybrid(subj_csv, op):
    vals = [r['hybrid'] for r in groups.get((subj_csv, op), [])]
    return (sum(vals) / len(vals)) if vals else None

def fmt(x):
    return f"{x:.3f}" if x is not None else "?.???"

print("**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**")
print()
print("| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |")
print("| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |")

for subj_csv, subj_label in subjects:
    linked_hy = fmt(stat_hybrid(subj_csv, 'Linked'))
    linked_ir = fmt(stat_inheritance(subj_csv, 'Linked'))
    one_hy = fmt(stat_hybrid(subj_csv, 'One Point'))
    one_ir = fmt(stat_inheritance(subj_csv, 'One Point'))
    two_hy = fmt(stat_hybrid(subj_csv, 'Two Point'))
    two_ir = fmt(stat_inheritance(subj_csv, 'Two Point'))

    # Match the column-style alignment of the expected table (subject column width 7)
    subj_cell = subj_label.ljust(7)
    print(f"| {subj_cell} | {linked_hy:>8} | {linked_ir:>8} | {one_hy:>11} | {one_ir:>11} | {two_hy:>11} | {two_ir:>11} |")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
