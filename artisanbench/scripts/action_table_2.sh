#!/usr/bin/env bash

IMAGE="islemdockerdev/github-workflow-resource-study:v1.1"
NAME="github-study"
docker pull "$IMAGE"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name "$NAME" "$IMAGE" -c "sleep infinity"

docker exec "$NAME" /bin/bash --noprofile --norc -c "pip install --no-cache-dir jupyter"
docker exec "$NAME" /bin/bash --noprofile --norc -c "cd /workdir && pip install ."
docker exec "$NAME" /bin/bash --noprofile --norc -c \
  "jupyter nbconvert --to markdown --execute /workdir/paper_analysis_RQ1.ipynb --output rq1 --output-dir /workdir --ExecutePreprocessor.timeout=14400"

docker exec "$NAME" /bin/bash --noprofile --norc -c "cat /workdir/rq1.md" > /workspace/rq1.md

echo "<artisan_submit>"
python3 - <<'PY'
from __future__ import annotations
import re
from pathlib import Path

order = ["test","build","release","analyze","lint","linux","update","integration","deploy","sync"]
want = set(order)

txt = Path("/workspace/rq1.md").read_text(encoding="utf-8", errors="replace").splitlines()

# 1) Find Table 2 heading in the markdown produced by nbconvert (it is a "## ..." heading).
start = None
for i, ln in enumerate(txt):
    s = ln.strip()
    if s.startswith("## ") and "Resource usage by task" in s and "Table 2" in s:
        start = i
        break
if start is None:
    raise SystemExit("Could not find '## Resource usage by task (Table 2 ...)' heading in /workspace/rq1.md")

# 2) End at next "## ..." heading
end = None
for i in range(start + 1, len(txt)):
    if txt[i].strip().startswith("## "):
        end = i
        break
section = txt[start:end]

# 3) In this section, nbconvert includes the printed table as fixed-width text.
#    We locate the row header line that begins with "Task" (often indented).
hdr = None
for i, ln in enumerate(section):
    if re.match(r"^\s*Task\s+Paid\s+Free\s+Paid\s+Free\s+Paid", ln):
        hdr = i
        break
if hdr is None:
    # Helpful excerpt
    excerpt = "\n".join(section[:120])
    raise SystemExit("Could not find the printed 'Task  Paid Free ...' header line in Table 2 section.\n"
                     "Section excerpt:\n" + excerpt)

# 4) Parse rows after the dashed separator line(s).
# Example row (from your rq1.md):
# test  54.6  37.3  50.9  36.2  8.1 (iqr=7.2)  1.5 (iqr=1.3)  0.1  0.02
row_re = re.compile(
    r"^\s*(?P<task>[A-Za-z_]+)\s+"
    r"(?P<vm_paid>\d+(?:\.\d+)?)\s+(?P<vm_free>\d+(?:\.\d+)?)\s+"
    r"(?P<runs_paid>\d+(?:\.\d+)?)\s+(?P<runs_free>\d+(?:\.\d+)?)\s+"
    r"(?P<vmpr_paid>\d+(?:\.\d+)?)\s*\(iqr=(?P<iqr_paid>\d+(?:\.\d+)?)\s*\)\s+"
    r"(?P<vmpr_free>\d+(?:\.\d+)?)\s*\(iqr=(?P<iqr_free>\d+(?:\.\d+)?)\s*\)\s+"
    r"(?P<cost_paid>\d+(?:\.\d+)?)\s+(?P<cost_free>\d+(?:\.\d+)?)\s*$"
)

rows: dict[str, tuple[str,str,str,str,str,str,str,str]] = {}

for ln in section[hdr+1:]:
    # Stop if we hit something that looks like the next major part (extra safety).
    if ln.strip().startswith("## "):
        break

    m = row_re.match(ln)
    if not m:
        continue

    task = m.group("task").strip().lower()
    if task not in want:
        continue

    def f1(x: str) -> str: return f"{float(x):.1f}"
    def f2(x: str) -> str: return f"{float(x):.2f}"
    def mean_iqr(mean: str, iqr: str) -> str: return f"{float(mean):.1f} ({float(iqr):.1f})"

    rows[task] = (
        f1(m.group("vm_paid")),
        f1(m.group("vm_free")),
        f1(m.group("runs_paid")),
        f1(m.group("runs_free")),
        mean_iqr(m.group("vmpr_paid"), m.group("iqr_paid")),
        mean_iqr(m.group("vmpr_free"), m.group("iqr_free")),
        f2(m.group("cost_paid")),
        f2(m.group("cost_free")),
    )

missing = [t for t in order if t not in rows]
if missing:
    # Print a compact debug excerpt around the header to show what we saw.
    around = "\n".join(section[max(0, hdr-10):hdr+80])
    raise SystemExit(
        "Missing expected tasks in parsed table rows: " + ", ".join(missing)
        + "\nParsed tasks: " + (", ".join(sorted(rows.keys())) if rows else "(none)")
        + "\n\nExcerpt around the table header:\n" + around
    )

print("**Table 2: Summary of resource consumption by CI/CD tasks.**\n")
print("| Task        | VM time % (Paid) | VM time % (Free) | Runs % (Paid) | Runs % (Free) | VM time per run, min (Paid) | VM time per run, min (Free) | VM cost per run, $ (Paid) | VM cost per run, $ (Free) |")
print("| ----------- | ---------------: | ---------------: | ------------: | ------------: | --------------------------: | --------------------------: | ------------------------: | ------------------------: |")
for t in order:
    a,b,c,d,e,f,i,j = rows[t]
    name = t.capitalize() if t != "integration" else "Integration"
    print(f"| {name:<11} | {a:>15} | {b:>15} | {c:>12} | {d:>12} | {e:>26} | {f:>26} | {i:>24} | {j:>24} |")
print("\n* mean (inter-quartile range)")
PY
echo "</artisan_submit>"
