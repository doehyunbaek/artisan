#!/usr/bin/env bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o NeuroJIT.zip https://zenodo.org/api/records/13744025/files/NeuroJIT.zip/content
unzip -q NeuroJIT.zip -d NeuroJIT

# Keep the full raw log
(cd NeuroJIT && docker-compose up --build) > /workspace/repro.txt 2>&1

# Create a tail view for parsing/debugging, without overwriting repro.txt
tail -n 200 /workspace/repro.txt > /workspace/repro_tail_200.txt

echo '<artisan_submit>'
python3 - <<'PY'
import re

raw = open("/workspace/repro_tail_200.txt", encoding="utf-8", errors="replace").read()
raw = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", raw)
raw = re.sub(r"^.*?\|\s", "", raw, flags=re.M)

lines = raw.splitlines()
marker = "[Table 3] Average Ratios of Actionable Features within Top 5 Contribution Rankings of LIME Explanations"
start_idx = next((i for i, ln in enumerate(lines) if marker in ln), None)
if start_idx is None:
    raise SystemExit("ERROR: could not find [Table 3] marker")
lines = lines[start_idx:]

def find_first(label: str):
    for i, ln in enumerate(lines):
        if ln.strip() == label:
            return i
    return None

rf_i = find_first("Random Forest")
xgb_i = find_first("XGBoost")
if rf_i is None or xgb_i is None or xgb_i <= rf_i:
    raise SystemExit("ERROR: could not find Random Forest / XGBoost markers")

rf_lines = lines[rf_i:xgb_i]
xgb_lines = lines[xgb_i:]

row_re = re.compile(
    r"^\s*[│|]\s*([A-Za-z]+|Average)\s*[│|]\s*([0-9]+(?:\.[0-9]+)?)\s*[│|]\s*([0-9]+(?:\.[0-9]+)?)\s*[│|]\s*(.*?)\s*[│|]\s*$"
)

def parse_block(block_lines):
    out = {}
    for ln in block_lines:
        m = row_re.match(ln)
        if not m:
            continue
        proj = m.group(1).strip().lower()
        base = float(m.group(2))
        comb = float(m.group(3))
        rest = m.group(4)

        eff = None
        m2 = re.search(r"\[([lsm\*])\]", rest)
        if m2:
            code = m2.group(1)
            if code == "*":
                eff = "n" if proj == "hive" else None   # keep only for Hive
            else:
                eff = code

        out[proj] = (base, comb, eff)
    return out

rf = parse_block(rf_lines)
xg = parse_block(xgb_lines)

name_map = {
    "activemq": "ActiveMQ",
    "camel": "Camel",
    "flink": "Flink",
    "groovy": "Groovy",
    "cassandra": "Cassandra",
    "hbase": "HBase",
    "hive": "Hive",
    "ignite": "Ignite",
    "average": "Average (%)",
}
order = ["activemq","camel","flink","groovy","cassandra","hbase","hive","ignite","average"]

def fmt_comb(v: float, eff):
    return f"{v:.1f} ({eff})" if eff is not None else f"{v:.1f}"

print("**Table 3: Average Ratios of Actionable Features within Top 5 Contribution Rankings of LIME Explanations**")
print()
print("| Project | Random Forest (%) | | XGBoost (%) |  | ")
print("| --- | --- | --- | --- | --- |")
print("| | baseline | combined (δ) | baseline | combined |  |")

for k in order:
    if k not in rf or k not in xg:
        raise SystemExit(f"ERROR: missing row '{k}'")
    rf_b, rf_c, rf_e = rf[k]
    xg_b, xg_c, xg_e = xg[k]
    print(f"| {name_map.get(k,k)} | {rf_b:.1f} | {fmt_comb(rf_c, rf_e)} | {xg_b:.1f} | {fmt_comb(xg_c, xg_e)} |")

print()
PY
echo '</artisan_submit>'
