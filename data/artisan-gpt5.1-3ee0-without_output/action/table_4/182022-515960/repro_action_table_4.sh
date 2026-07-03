#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Prevalence and impact of workflows optimizations.**

| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |
| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |
| Cache                  | Off      |                   ??.? |                   ??.? |                  ???.? |                  ???.? |                       -?.? |                       -?.? |                            -??.?? |                             -?.?? |
| Fail-fast              | On       |                   ??.? |                   ??.? |                    ?.? |                    ?.? |                       -?.? |                       -?.? |                             -?.?? |                             -?.?? |
| Cancel-in-progress     | Off      |                   ??.? |                    ?.? |                    ?.? |                    ?.? |                       -?.? |                       -?.? |                            -??.?? |                             -?.?? |
| Skip workflow          | –        |                    ?.? |                    ?.? |                    ?.? |                    ?.? |                      <-?.? |                       -?.? |                             -?.?? |                             -?.?? |
| Filtering target files | Off      |                   ??.? |                    ?.? |                   <?.? |                    ?.? |                      <-?.? |                      <-?.? |                             -?.?? |                             -?.?? |
| Custom timeout         | 360 mins |                   ??.? |                    ?.? |                    ?.? |                    ?.? |                       -?.? |                      -??.? |                            -??.?? |                             -?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull and start the Docker container with the artifact environment
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --entrypoint bash --name github-study -v /workspace:/workspace islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
# Execute the RQ2 notebook code inside the container and emit a markdown version of Table 4 to /workspace/repro.txt
docker exec github-study /bin/bash --noprofile --norc -c "python - << 'PY'
import json, textwrap

nb_path = 'paper_analysis_RQ2.ipynb'
with open(nb_path) as f:
    nb = json.load(f)

code_blocks = []
for cell in nb.get('cells', []):
    if cell.get('cell_type') != 'code':
        continue
    src = ''.join(cell.get('source', []))
    # strip IPython magics or shell escapes if present
    filtered_lines = []
    for line in src.splitlines():
        stripped = line.lstrip()
        if stripped.startswith('%') or stripped.startswith('!'):
            continue
        filtered_lines.append(line)
    code_blocks.append('\n'.join(filtered_lines))

full_code = '\n\n'.join(code_blocks)
ns = {}
exec(full_code, ns, ns)

optimizations = ns.get('optimizations')
if optimizations is None:
    raise SystemExit('optimizations dict not found after executing notebook code')

def fmt(x, digits=1):
    return f'{round(float(x), digits):.{digits}f}'

def fmt2(x):
    return f'{round(float(x), 2):.2f}'

rows = []
rows.append('**Table 4: Prevalence and impact of workflows optimizations.**\\n')
rows.append('')
rows.append('| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |')
rows.append('| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |')

def add_row(name, default, key):
    o = optimizations[key]
    paid = o['paid']
    free = o['free']
    rows.append(
        f'| {name:<22} | {default:<8} | {fmt(paid[\"adoption\"]):>21} | {fmt(free[\"adoption\"]):>21} | '
        f'{fmt(paid[\"impacted_runs\"],1):>21} | {fmt(free[\"impacted_runs\"],1):>21} | '
        f'{\"-\"+fmt(paid[\"time_impact\"],1):>25} | {\"-\"+fmt(free[\"time_impact\"],1):>25} | '
        f'{\"-\"+fmt2(paid[\"cost_impact\"]):>30} | {\"-\"+fmt2(free[\"cost_impact\"]):>30} |'
    )

add_row('Cache', 'Off', 'cache')
add_row('Fail-fast', 'On', 'fail_fast')
add_row('Cancel-in-progress', 'Off', 'cancel_in_progress')
add_row('Skip workflow', '\u2013', 'skip_workflow')
add_row('Filtering target files', 'Off', 'filtering_target_files')
add_row('Custom timeout', '360 mins', 'custom_timeout')

with open('/workspace/repro.txt', 'w') as out_f:
    out_f.write('\n'.join(rows) + '\n')
PY"
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
