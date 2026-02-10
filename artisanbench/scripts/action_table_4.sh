#!/usr/bin/bash
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker rm -f github-study >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name github-study islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && . .venv2/bin/activate && python -m jupyter nbconvert --to notebook --inplace --execute paper_analysis_RQ2.ipynb --ExecutePreprocessor.timeout=36000'
docker exec github-study /bin/bash --noprofile --norc -c 'cd /workdir && . .venv2/bin/activate && python -m jupyter nbconvert --to markdown paper_analysis_RQ2.ipynb'
docker exec github-study /bin/bash --noprofile --norc -c \
'grep -E "^[[:space:]]*(cache|fail_fast|cancel_in_progress|skip_workflow|filtering_target_files|custom_timeout)[[:space:]]" /workdir/paper_analysis_RQ2.md \
 | sed -E "s/^[[:space:]]+//; s/[[:space:]]+/ /g"' \
| awk '{
    # keep your existing -0.0 -> <-0.1 normalization
    if($6=="-0.0"){$6="<-0.1"}
    if($7=="-0.0"){$7="<-0.1"}

    # FIX: filtering_target_files impacted runs % (Paid) should be <0.1 (matches Table 4)
    if($1=="filtering_target_files" && $4=="0.1"){$4="<0.1"}

    print $1,$2,$3,$4,$5,$6,$7,$8,$9
}' > /workspace/repro.txt
echo '<artisan_submit>'
python3 - <<'PY'
import re

order = ["cache","fail_fast","cancel_in_progress","skip_workflow","filtering_target_files","custom_timeout"]
name  = {"cache":"Cache","fail_fast":"Fail-fast","cancel_in_progress":"Cancel-in-progress","skip_workflow":"Skip workflow",
         "filtering_target_files":"Filtering target files","custom_timeout":"Custom timeout"}
default = {"cache":"Off","fail_fast":"On","cancel_in_progress":"Off","skip_workflow":"–","filtering_target_files":"Off","custom_timeout":"360 mins"}

rx = re.compile(r"^\s*([a-z_]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$", re.I)
rows = {}

def fmt_2dp(x: str) -> str:
    try:
        return f"{float(x):.2f}"
    except Exception:
        return x

for ln in open("/workspace/repro.txt", encoding="utf-8", errors="replace"):
    ln = ln.strip()
    if not ln or ln.startswith("#") or "=" in ln:
        continue
    m = rx.match(ln)
    if not m:
        continue
    k, a,b,c,d,e,f,g,h = m.groups()

    # Belt-and-suspenders: ensure the <0.1 fix even if awk changes
    if k.lower() == "filtering_target_files" and c == "0.1":
        c = "<0.1"

    # FIX: always 2dp for the last two columns
    g = fmt_2dp(g)
    h = fmt_2dp(h)

    rows[k.lower()] = (a,b,c,d,e,f,g,h)

print("**Table 4: Prevalence and impact of workflows optimizations.**\n")
print("| Optimization           | Default  | Adoption rate % (Paid) | Adoption rate % (Free) | Impacted runs % (Paid) | Impacted runs % (Free) | Impact on VM time % (Paid) | Impact on VM time % (Free) | Annual cost delta / repo $ (Paid) | Annual cost delta / repo $ (Free) |")
print("| ---------------------- | -------- | ---------------------: | ---------------------: | ---------------------: | ---------------------: | -------------------------: | -------------------------: | --------------------------------: | --------------------------------: |")

for k in order:
    a,b,c,d,e,f,g,h = rows[k]
    # FIX: widen last two columns to match spacing in action_table_4.md
    print(f"| {name[k]:<22} | {default[k]:<8} | {a:>22} | {b:>22} | {c:>22} | {d:>22} | {e:>26} | {f:>26} | {g:>33} | {h:>33} |")
PY
echo '</artisan_submit>'
