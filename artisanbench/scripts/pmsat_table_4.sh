#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o pmsat-inference-and-publication-artifacts.zip \
  https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content
unzip -o pmsat-inference-and-publication-artifacts.zip -d pmsat-inference-and-publication-artifacts

cd pmsat-inference-and-publication-artifacts/pmsat-inference
docker-compose build

docker rm -f pmsat_compose_container >/dev/null 2>&1 || true
docker run -d --init --name pmsat_compose_container \
  -v "$(pwd):/pmsat-inference" \
  --entrypoint bash pmsat-inference-pmsat -c 'sleep infinity'

docker exec pmsat_compose_container /bin/bash --noprofile --norc -lc \
  "cd /pmsat-inference && /opt/venv/bin/python3.10 run_pmsat_on_traces.py use_cases/avl_APC/apc_trace.json -nmax 13" \
  >> /workspace/repro.txt 2>&1

docker exec pmsat_compose_container /bin/bash --noprofile --norc -lc \
  "cd /pmsat-inference && /opt/venv/bin/pip install 'numpy<2'" \
  >> /workspace/repro.txt 2>&1

docker exec pmsat_compose_container /bin/bash --noprofile --norc -lc \
  "cd /pmsat-inference && /opt/venv/bin/python3.10 parse_single_run_results.py TRACE-results/cec0073ace4949b9131532f72e03f409" \
  >> /workspace/repro.txt 2>&1

echo "<artisan_submit>"
python3 - <<'PY'
import re

txt = open("/workspace/repro.txt", "r", encoding="utf-8", errors="replace").read().splitlines()

# Find header
hdr_i = None
for i, l in enumerate(txt):
    if l.strip().startswith("n,n_reach") and "Mean" in l and "Max" in l and "Min" in l:
        hdr_i = i
        break
if hdr_i is None:
    raise SystemExit("Could not find parse_single_run_results header in /workspace/repro.txt")

def normalize_cell_keep_leftpad(s: str) -> str:
    # keep original leading spaces, remove trailing newline/CR
    s = s.rstrip("\r\n")
    lead = len(s) - len(s.lstrip(" "))
    core = s.strip()

    # convert things like 3.0 -> 3 (only when it's exactly an integer value)
    try:
        f = float(core)
        if f.is_integer():
            core = str(int(f))
    except Exception:
        pass

    return (" " * lead) + core

rows = []
for l in txt[hdr_i + 1:]:
    if not l.strip():
        break
    if not re.match(r"^\s*\d+\s*,", l):
        break

    parts = l.split(",")
    if len(parts) < 6:
        continue

    n = parts[0].strip()  # normalize key for matching
    n_reach = normalize_cell_keep_leftpad(parts[1])
    glitches = normalize_cell_keep_leftpad(parts[2])
    mean_dg = normalize_cell_keep_leftpad(parts[3])
    max_dg = normalize_cell_keep_leftpad(parts[4])
    min_d = normalize_cell_keep_leftpad(parts[5])

    rows.append((n, n_reach, glitches, mean_dg, max_dg, min_d))

r7 = next((r for r in rows if r[0] == "7"), None)
if r7 is None:
    raise SystemExit("Could not find row for n=7")

_, n_reach, glitches, mean_dg, max_dg, min_d = r7

print("**Table 4: Statistics of inferring the APC with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**\n")
print("|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |")
print("| -: | ------: | ---------: | -----------: | ----------: | --------: |")
print(f"|  7 | {n_reach} | {glitches} | {mean_dg} | {max_dg} | {min_d} |")
print()  # ensure trailing newline at EOF
PY
echo "</artisan_submit>"

