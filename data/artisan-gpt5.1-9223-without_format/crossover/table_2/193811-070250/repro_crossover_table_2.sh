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
# Download the artifact from Figshare
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879
# Section 3: Reproduction commands (populate from reviewed steps)
# Load the Docker image, start the artifact container, and compute Table 2 into /workspace/repro.txt
docker load -i /workspace/zeugma-artifact-image.tgz
docker rm -f zeugma-artifact || true
docker run -d --init --name zeugma-artifact --entrypoint bash zeugma-artifact:latest -c 'sleep infinity'
docker exec zeugma-artifact /bin/bash --noprofile --norc -c "cd /home && python3 - << 'PY'
import sys
import pandas as pd

# Make artifact analysis modules available
sys.path.append('scripts')
import report_util, tables  # type: ignore[import]

# Load heritability data using the artifact's helper (no time column here)
data = report_util.read_timedelta_csv('data/heritability.csv')

# Reuse the artifact's table-building logic to ensure identical statistics
ir = tables.create_stat_table(
    data,
    x='crossover_operator',
    baseline_x='Linked',
    y='inheritance_rate',
    columns=['subject'],
)
ir['metric'] = 'IR'

hy = tables.create_stat_table(
    data,
    x='crossover_operator',
    baseline_x='Linked',
    y='hybrid',
    columns=['subject'],
)
hy['metric'] = 'HY'

table = pd.concat([ir, hy])
stats = tables.pivot(
    table,
    col='crossover_operator',
    row='subject',
    col2='metric',
    value='stat',
)

subjects = ['Ant', 'Bcel', 'Closure', 'Maven', 'Nashorn', 'Rhino', 'Tomcat']
display_names = {'Bcel': 'BCEL'}
crossover_order = ['Linked', 'One Point', 'Two Point']
metrics = ['HY', 'IR']

print('**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**')
print()
print('| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |')
print('| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |')

for subject in subjects:
    values = []
    for crossover in crossover_order:
        for metric in metrics:
            value = stats.loc[subject, (crossover, metric)]
            values.append(f'{value:.3f}')
    name = display_names.get(subject, subject)
    row = ' | '.join(f'{v:>7}' for v in values)
    print(f'| {name:<7} | {row} |')
PY" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
