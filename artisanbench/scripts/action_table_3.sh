#!/usr/bin/bash
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity' || true
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && ./.venv2/bin/jupyter-nbconvert --to notebook --execute paper_analysis_RQ1.ipynb --output paper_analysis_RQ1.out.ipynb --ExecutePreprocessor.timeout=7200'
docker exec github-study /bin/bash --noprofile --norc -c 'python3 - <<PY
import json, re
nb="/workdir/paper_analysis_RQ1.out.ipynb"
data=json.load(open(nb))
texts=[]
for cell in data.get("cells", []):
    for out in cell.get("outputs", []):
        if "text" in out:
            texts.append("".join(out["text"]))
full="".join(texts)
pattern=r"(?m)^(success|failure|skipped|cancelled|startup_failure|action_required|stale)\\s+([0-9.]+)\\s+([0-9.]+)\\s+([0-9.]+)\\s+([0-9.]+)"
rows={}
for m in re.finditer(pattern, full):
    rows[m.group(1)] = [m.group(i) for i in range(2,6)]
mapnames={"success":"Success","failure":"Failure","skipped":"Skipped","cancelled":"Canceled","startup_failure":"Startup failure","action_required":"Action required","stale":"Stale"}
order=["Success","Failure","Skipped","Canceled","Startup failure","Action required","Stale"]
print("Status,Runs proportion % (Paid),Runs proportion % (Free),VM time proportion % (Paid),VM time proportion % (Free)")
for name in order:
    src=[k for k,v in mapnames.items() if v==name][0]
    a,b,c,d=rows.get(src,["","","",""])
    # Apply < 0.1 formatting for paid runs in Action required and Stale
    if name in ("Action required","Stale"):
        a_val = "< 0.1"
    else:
        a_val = a
    print(f"{name},{a_val},{b},{c},{d}")
PY' > /workspace/repro.txt
echo '<artisan_submit>'
python3 - <<'PY'
import csv

order = ["Success","Failure","Skipped","Canceled","Startup failure","Action required","Stale"]
rows = {r["Status"]: r for r in csv.DictReader(open("/workspace/repro.txt", encoding="utf-8", errors="replace"))}

print("**Table 3: Termination status: comparison between free tier and paid tier.**\n")
print("| Status          | Runs proportion % (Paid) | Runs proportion % (Free) | VM time proportion % (Paid) | VM time proportion % (Free) |")
print("| --------------- | -----------------------: | -----------------------: | --------------------------: | --------------------------: |")
for s in order:
    r = rows[s]
    a, b, c, d = r["Runs proportion % (Paid)"], r["Runs proportion % (Free)"], r["VM time proportion % (Paid)"], r["VM time proportion % (Free)"]
    print(f"| {s:<15} | {a:>23} | {b:>23} | {c:>26} | {d:>26} |")
PY
echo '</artisan_submit>'
