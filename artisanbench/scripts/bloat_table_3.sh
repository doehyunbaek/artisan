#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o bloat-study-artifact-v1.0.zip \
  https://zenodo.org/api/records/11095274/files/gdrosos/bloat-study-artifact-v1.0.zip/content

unzip -o bloat-study-artifact-v1.0.zip
cd /workspace/gdrosos-bloat-study-artifact-0fe2fe5

docker build -t bloat-study-artifact .

docker rm -f bloat_container >/dev/null 2>&1 || true
docker run -d --init --name bloat_container --entrypoint bash \
  -v /workspace/gdrosos-bloat-study-artifact-0fe2fe5:/home/user \
  bloat-study-artifact -c 'sleep infinity'

docker exec bloat_container /bin/bash --noprofile --norc -c \
  "python scripts/rq4.py data/results/qualitative_results.json --table3" \
  > /workspace/repro_raw.txt

python3 - <<'PY'
import re

raw = open("/workspace/repro_raw.txt", encoding="utf-8", errors="replace").read().splitlines()

# Parse rows like: | Merged      |              30 |                      35 |
row_re = re.compile(r'^\|\s*([A-Za-z]+)\s*\|\s*([0-9]+)\s*\|\s*([0-9]+)\s*\|')
rows = []
for l in raw:
    m = row_re.match(l)
    if m:
        status = m.group(1)
        prs = int(m.group(2))
        bd  = int(m.group(3))
        rows.append((status, prs, bd))

if not rows:
    raise SystemExit("ERROR: could not parse table rows from /workspace/repro_raw.txt")

row_map = {s.lower(): (s, prs, bd) for s, prs, bd in rows}

order = ["merged", "approved", "rejected", "pending", "total"]

def get(k: str):
    if k not in row_map:
        return None
    return row_map[k]

out = []
out.append("**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**")
out.append("")
out.append("| PR status | # of PRs | # of BD removed |")
out.append("| --------- | -------: | --------------: |")

for k in order:
    r = get(k)
    if r is None:
        continue
    label, prs, bd = r
    if k == "total":
        out.append(f"| **Total** | **{prs}** | **{bd}** |")
    else:
        out.append(f"| {label} | {prs} | {bd} |")

open("/workspace/repro.txt", "w", encoding="utf-8").write("\n".join(out) + "\n")
PY

echo "<artisan_submit>"
cat /workspace/repro.txt
echo "</artisan_submit>"
