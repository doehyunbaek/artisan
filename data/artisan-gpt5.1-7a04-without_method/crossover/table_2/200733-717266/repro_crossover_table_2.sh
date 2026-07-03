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
# Use Python (standard library only) to compute HY and IR per subject/operator from heritability.csv
python3 - <<'PY'
import csv
import statistics
from collections import defaultdict

input_file = 'heritability.csv'
output_file = '/workspace/repro.txt'

# Nested dict: stats[subject][operator] = {'hy': [...], 'ir': [...]}
stats = defaultdict(lambda: defaultdict(lambda: {'hy': [], 'ir': []}))

with open(input_file, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        subject = row['subject'].strip()
        op = row['crossover_operator'].strip()
        hy_str = str(row['hybrid']).strip().lower()
        hy_val = hy_str == 'true'
        ir_val = float(row['inheritance_rate'])
        stats[subject][op]['hy'].append(hy_val)
        stats[subject][op]['ir'].append(ir_val)

# Subjects appear in the paper in this order; 'Bcel' in the data is shown as 'BCEL'
subject_order = ['Ant', 'Bcel', 'Closure', 'Maven', 'Nashorn', 'Rhino', 'Tomcat']
display_name = {
    'Ant': 'Ant',
    'Bcel': 'BCEL',
    'Closure': 'Closure',
    'Maven': 'Maven',
    'Nashorn': 'Nashorn',
    'Rhino': 'Rhino',
    'Tomcat': 'Tomcat',
}
op_order = ['Linked', 'One Point', 'Two Point']

def get_metrics(subj, op):
    # Allow for small capitalization differences if ever present
    key = subj
    if key not in stats:
        for s in stats:
            if s.lower() == subj.lower():
                key = s
                break
    if key not in stats or op not in stats[key]:
        return '---', '---'
    entry = stats[key][op]
    if not entry['hy'] or not entry['ir']:
        return '---', '---'
    hy_mean = sum(entry['hy']) / len(entry['hy'])
    ir_median = statistics.median(entry['ir'])
    return f"{hy_mean:.3f}", f"{ir_median:.3f}"

lines = []
lines.append("| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |")
lines.append("| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |")

for subj in subject_order:
    # Skip subject if completely absent (defensive; should not happen here)
    if all(subj.lower() != s.lower() for s in stats.keys()):
        continue
    disp = display_name.get(subj, subj)
    metrics = []
    for op in op_order:
        hy, ir = get_metrics(subj, op)
        metrics.extend([hy, ir])
    line = f"| {disp:<7} | {metrics[0]:>8} | {metrics[1]:>8} | {metrics[2]:>11} | {metrics[3]:>11} | {metrics[4]:>11} | {metrics[5]:>11} |"
    lines.append(line)

with open(output_file, 'w', encoding='utf-8') as out:
    out.write("\n".join(lines) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
