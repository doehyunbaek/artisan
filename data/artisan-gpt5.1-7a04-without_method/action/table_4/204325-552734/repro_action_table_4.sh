#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<EOTABLE
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

# Section 3: Reproduction commands
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --name github-study-table4 -v /workspace:/workspace --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c "sleep infinity"

# Python helper script: execute RQ2 notebook cells and emit Table 4 as Markdown
cat > /workspace/run_rq2_table_4.py << 'PY'
import os
import json
import io
import sys

# Ensure the artifact code is importable
os.chdir("/workdir")
sys.path.insert(0, os.path.join(os.getcwd(), "src"))

# Load the RQ2 notebook
with open("paper_analysis_RQ2.ipynb") as f:
    nb = json.load(f)

# Execute notebook code cells up to (but not including) the final printing cell
ns = {}
buf = io.StringIO()
old_stdout = sys.stdout
sys.stdout = buf
try:
    for cell in nb.get("cells", []):
        if cell.get("cell_type") != "code":
            continue
        src = "".join(cell.get("source", []))
        if not src.strip():
            continue
        if "print(\"{:<30} {:<24} {:<24} {:<24} {:<24}\".format(" in src:
            break
        exec(src, ns)
finally:
    sys.stdout = old_stdout

optimizations = ns["optimizations"]

# Emit the final Table 4 as a Markdown table
print("**Table 4: Prevalence and impact of workflows optimizations.**")
print()
header = "| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |"
sep =    "| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |"
print(header)
print(sep)

rows = [
    ("Cache", "Off", "cache"),
    ("Fail-fast", "On", "fail_fast"),
    ("Cancel-in-progress", "Off", "cancel_in_progress"),
    ("Skip workflow", "\u2013", "skip_workflow"),
    ("Filtering target files", "Off", "filtering_target_files"),
    ("Custom timeout", "360 mins", "custom_timeout"),
]

for name, default, key in rows:
    o = optimizations[key]
    pa = round(o["paid"]["adoption"], 1)
    fa = round(o["free"]["adoption"], 1)
    pir = round(o["paid"]["impacted_runs"], 1)
    fir = round(o["free"]["impacted_runs"], 1)
    pt = round(o["paid"]["time_impact"], 1)
    ft = round(o["free"]["time_impact"], 1)
    pc = round(o["paid"]["cost_impact"], 2)
    fc = round(o["free"]["cost_impact"], 2)
    # Negative sign denotes savings
    print(f"| {name:<22} | {default:<8} | {pa:21.1f} | {fa:21.1f} | {pir:21.1f} | {fir:21.1f} | {(-pt):25.1f} | {(-ft):25.1f} | {(-pc):32.2f} | {(-fc):32.2f} |")
PY

# Run the helper inside the container to produce /workspace/repro.txt
docker exec github-study-table4 /bin/bash --noprofile --norc -c "python /workspace/run_rq2_table_4.py" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo "<artisan_submit>"
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo "</artisan_submit>"
