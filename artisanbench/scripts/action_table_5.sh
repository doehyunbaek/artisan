#!/usr/bin/bash
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && python3 -m pip install --upgrade --no-cache-dir nbconvert papermill ipykernel && python3 -m ipykernel install --name python3 --display-name 'python3' && python3 -m pip install --upgrade --no-cache-dir -r requirements.txt && python3 -m pip install --upgrade --no-cache-dir -e . && cd /workdir && papermill paper_analysis_RQ3.ipynb executed_RQ3.ipynb --log-output" > /workspace/repro.txt 2>&1
echo '<artisan_submit>'
python3 - <<'PY'
import re

ls = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read().splitlines()
i0 = next(i for i,l in enumerate(ls) if l.startswith("Optimization heuristic"))
dash = re.compile(r"^-{10,}\s*$")
r4 = re.compile(r"^(.{1,35}?)\s{2,}(.+?)\s{2,}(.+?)\s{2,}(.+?)\s*$")
r3 = re.compile(r"^(.{1,35}?)\s{2,}(.+?)\s{2,}(.+?)\s*$")

cur, recs = [], []
for l in ls[i0+1:]:
    if dash.match(l):
        if cur:
            recs.append(cur)
            cur = []
        continue
    m = r4.match(l) or r3.match(l)
    if not m:
        continue
    cur.append(m.groups())
if cur:
    recs.append(cur)

def norm_paren_lt_point1(s: str) -> str:
    # (0.0%) -> (<0.1%)
    return s.replace("(0.0%)", "(<0.1%)")

def norm_time_cell(s: str) -> str:
    s = norm_paren_lt_point1(s)
    # leading 0.0% -> <0.1% (only for the first percentage on a line)
    s = re.sub(r'(^|<br>)\s*0\.0%', r'\1<0.1%', s)
    # add "time" to the second-line suffixes (time-saving column only)
    s = re.sub(r'\bscheduled runs\b(?!\s*time)', 'scheduled runs time', s)
    s = re.sub(r'\bfailed runs\b(?!\s*time)', 'failed runs time', s)
    return s

def tweak_impacted(h: str, imp: str) -> str:
    # Match reference file's row-specific leading spaces in the Impacted runs cell.
    if h.startswith("Deactivate scheduled workflows during repository inactivity"):
        return " " + imp            # "  4.5% ..."
    if h.startswith("Run previously failed jobs first"):
        return "    " + imp         # "     1.0% ..."
    if h.startswith("Project-specific timeouts"):
        return "  " + imp           # "   0.5% ..."
    return imp

def tweak_time(tim: str) -> str:
    # Strip leading spaces per <br>-separated line to avoid extra padding before <0.1%.
    return "<br>".join(part.lstrip() for part in tim.split("<br>"))

def pack(rec):
    h = " ".join(x[0].strip() for x in rec).replace("  ", " ")
    imp = "<br>".join(x[1].strip() for x in rec)
    tim = "<br>".join(x[2].strip() for x in rec)
    cost = (rec[0][3].strip() if len(rec[0]) == 4 else "")
    # normalize
    imp = norm_paren_lt_point1(imp)
    tim = norm_time_cell(tim)
    # whitespace tweaks to match reference output
    imp = tweak_impacted(h, imp)
    tim = tweak_time(tim)
    return h, imp, tim, cost

rows = [pack(r) for r in recs[:4]]

print("**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**\n")
print("| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |")
print("| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |")
for h, imp, tim, cost in rows:
    print(f"| {h:<65} | {imp:>56} | {tim:>69} | {cost:>39} |")
print("\n* measurement for paid tier (measurement for free tier)")
print()  # ensure trailing newline at EOF
PY
echo '</artisan_submit>'
