#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o lasapp-amd64.tar \
  https://zenodo.org/api/records/15857114/files/lasapp-amd64.tar/content

: > /workspace/repro.txt

tar xf lasapp-amd64.tar
docker load -i lasapp-amd64.tar

docker run -d --init --name lasapp-amd64 lasapp-amd64 sleep infinity >> /workspace/repro.txt 2>&1
sleep 2
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "./scripts/start_servers.sh" >> /workspace/repro.txt 2>&1
sleep 2
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl turing" >> /workspace/repro.txt 2>&1
sleep 2
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "python3 experiments/evaluate_graph_and_constraints.py -ppl pymc" >> /workspace/repro.txt 2>&1
sleep 2
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "python3 experiments/evaluate_hmc.py" >> /workspace/repro.txt 2>&1
sleep 2
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "python3 experiments/evaluate_guide.py" >> /workspace/repro.txt 2>&1
echo '<artisan_submit>'
python3 - <<'PY'
import re
from pathlib import Path

repro = Path("/workspace/repro.txt").read_text(errors="replace")

# --- Parse Turing/PyMC summary pairs (first pair = Turing, second = PyMC) ---
mg = re.findall(r"Model Graph\s+Error Count:\s*([0-9]+)\s*/\s*([0-9]+)", repro)
cg = re.findall(r"Constraint\s+Error Count:\s*([0-9]+)\s*/\s*([0-9]+)", repro)

def pick_pair(pairs, idx):
    if len(pairs) <= idx:
        return None
    a, b = pairs[idx]
    return int(a), int(b)

t_mg = pick_pair(mg, 0)
p_mg = pick_pair(mg, 1)
t_cg = pick_pair(cg, 0)
p_cg = pick_pair(cg, 1)

# --- Parse Gen warnings (last "k / n warnings." within gen block) ---
gen_block = ""
m = re.search(r"## evaluation/gen/.*?(?=## evaluation/pyro/|\Z)", repro, flags=re.S)
if m:
    gen_block = m.group(0)
gen_warns = re.findall(r"([0-9]+)\s*/\s*([0-9]+)\s+warnings\.", gen_block)
gen_k, gen_n = (int(gen_warns[-1][0]), int(gen_warns[-1][1])) if gen_warns else (None, None)

# --- Parse Pyro warnings (last "k / n warnings." within pyro block) ---
pyro_block = ""
m = re.search(r"## evaluation/pyro/.*?\Z", repro, flags=re.S)
if m:
    pyro_block = m.group(0)
pyro_warns = re.findall(r"([0-9]+)\s*/\s*([0-9]+)\s+warnings\.", pyro_block)
pyro_k, pyro_n = (int(pyro_warns[-1][0]), int(pyro_warns[-1][1])) if pyro_warns else (None, None)

def cell(x):
    return "?" if x is None else str(x)

# Table semantics:
# - Dependency Analysis warnings := Model Graph error count
# - Constraint Verifier warnings := Constraint error count
t_total = t_mg[1] if t_mg else None
p_total = p_mg[1] if p_mg else None

rows = [
    ("Dependency Analysis",    "Turing", t_total, (t_mg[0] if t_mg else None)),
    ("Dependency Analysis",    "PyMC",   p_total, (p_mg[0] if p_mg else None)),
    ("Constraint Verifier",    "Turing", t_total, (t_cg[0] if t_cg else None)),
    ("Constraint Verifier",    "PyMC",   p_total, (p_cg[0] if p_cg else None)),
    ("HMC Assumption Checker", "Gen",    gen_n,   gen_k),
    ("Model-Guide Validator",  "Pyro",   pyro_n,  pyro_k),
]

# Build markdown
header = "**Table 2: Summary tables of evaluation results.**\n"
table_lines = [
    "",
    "| Analysis               | PPL    | Total Programs | Warnings produced  |",
    "| ---------------------- | ------ | -------------: | ----------------:  |",
]
for analysis, ppl, total, warns in rows:
    table_lines.append(f"| {analysis:<22} | {ppl:<6} | {cell(total):>13} | {cell(warns):>17} |")

final_md = header + "\n".join(table_lines) + "\n"

# Optional: save for inspection
Path("/workspace/final.md").write_text(final_md)

print(final_md, end="")
PY
echo '</artisan_submit>'
