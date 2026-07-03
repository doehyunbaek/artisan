#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**

| k                     |    1 |    2 |    5 |   10 |   15 |   20 |
| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |
| Impact on VM time (%) | -?.? | -?.? | -?.? | -?.? | -?.? | -?.? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665
# Section 3: Reproduction commands (extract outputs from notebook to avoid heavy runtime deps)
python3 - <<'PY'
import json, re, sys
nb_path='gh_resource_study_artifact_patched/github-workflow-resource-optimization/paper_analysis_RQ3.ipynb'
with open(nb_path,'r',encoding='utf-8') as f:
    nb=json.load(f)
lines=[]
for cell in nb.get('cells',[]):
    for out in cell.get('outputs',[]):
        # collect textual outputs
        if 'text' in out:
            txt = out.get('text')
            if isinstance(txt, str):
                lines.extend(txt.splitlines())
            elif isinstance(txt, list):
                lines.extend(txt)
        # sometimes outputs are in data->text/plain
        if 'data' in out and isinstance(out['data'], dict):
            tp = out['data'].get('text/plain')
            if tp:
                if isinstance(tp, str):
                    lines.extend(tp.splitlines())
                elif isinstance(tp, list):
                    lines.extend(tp)
# parse lines for k values
pat = re.compile(r'^\s*(1|2|5|10|15|20)\s+([0-9]+(?:\.[0-9]+)?)')
vals = {}
for L in lines:
    m = pat.match(L)
    if m:
        k = int(m.group(1))
        v = float(m.group(2))
        vals[k]=v
# Build markdown reproduction table
ks=[1,2,5,10,15,20]
row_vals = []
for k in ks:
    v = vals.get(k)
    if v is None:
        row_vals.append('-?.?')
    else:
        row_vals.append('{:.1f}'.format(v))
md = """**Table 6: Sensitivity of deactivating scheduled workflows to the parameter k.**

| k                     |    1 |    2 |    5 |   10 |   15 |   20 |
| --------------------- | ---: | ---: | ---: | ---: | ---: | ---: |
| Impact on VM time (%) | {} | {} | {} | {} | {} | {} |
""".format(*[s.rjust(5) for s in row_vals])
with open('/workspace/repro.txt','w',encoding='utf-8') as out:
    out.write(md)
print('WROTE /workspace/repro.txt')
PY
# Section 4: Formatting (will be run when the script is executed)
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
