#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ASE24_data_and_tools.zip https://zenodo.org/api/records/13741330/files/ASE24_data_and_tools.zip/content
unzip ASE24_data_and_tools.zip -d ASE24_data_and_tools
python - << 'PY'
import csv, math
from pathlib import Path

csv_path = Path("ASE24_data_and_tools/ASE24_data_and_tools/results_data/execution/conf_1_global/executionsData.csv")

columns = ['directDepNumber', 'releaseSize', 'artifactSize', 'dependencySize', 'versionSize']
label_map = {
    'directDepNumber': "(p)’s direct dependencies",
    'releaseSize': "releases ((N_R))",
    'artifactSize': "libraries ((N_L))",
    'dependencySize': "dependency edges ((E_D))",
    'versionSize': "versions edges ((E_V))",
}

data = {c: [] for c in columns}
with csv_path.open(newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        for c in columns:
            v = row.get(c)
            if v is None or v == '':
                continue
            data[c].append(float(v))

def pandas_percentile(values, q):
    vs = sorted(values)
    n = len(vs)
    if n == 1:
        return vs[0]
    pos = (n - 1) * q
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return vs[lo]
    frac = pos - lo
    return vs[lo] + frac * (vs[hi] - vs[lo])

def fmt_q(x):
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return f"{x:.1f}"

lines = []
lines.append("**Table 2: Demographics of our dataset of 107 Java projects**")
lines.append("")
lines.append("|                           |    Q1 |  Q2 |   Q3 | min |     max |")
lines.append("| ------------------------- | ----: | --: | ---: | --: | ------: |")

for c in columns:
    vs = data[c]
    q1 = pandas_percentile(vs, 0.25)
    q2 = pandas_percentile(vs, 0.5)
    q3 = pandas_percentile(vs, 0.75)
    mn = min(vs)
    mx = max(vs)
    q1_str = fmt_q(q1)
    q2_str = fmt_q(q2)
    q3_str = fmt_q(q3)
    mn_str = f"{int(round(mn)):,}"
    mx_str = f"{int(round(mx)):,}"
    lines.append(f"| {label_map[c]} | {q1_str} | {q2_str} | {q3_str} | {mn_str} | {mx_str} |")

out_path = Path("/workspace/repro.txt")
out_path.write_text("\n".join(lines))
PY

echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
