#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 2: Occurrences of desugared Kotlin syntactic sugars found in 2019/Java Boa dataset

| Syntactic Sugar | Java Method # | Java Method % |
| :--- | :--- | :--- |
| String Interpolation | ?,???,??? | ?.???% |
| Elvis Operator | ???,??? | ?.???% |
| Getter/Setter Properties | ?,???,??? | ?.???% |
| Not-Null Assertion | ???,??? | ?.???% |
| **Total:** | **???,???,???** | **???%** |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10460716 
# Section 3: Reproduction commands (populate from reviewed steps)
python - <<'PY'
import csv
from decimal import Decimal, ROUND_HALF_UP

csv_path = 'DDEBSSD-RP/DDEBSSD-RP/Kotlin-Desugars-Mined/results.csv'
rows = []
with open(csv_path, 'r', encoding='utf-8-sig', newline='') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

name_map = {
    'String Interpolation': 'String Interpolation',
    'Elvis Operator': 'Elvis Operator',
    'Get/Set Property': 'Getter/Setter Properties',
    'Not-Null Assertion': 'Not-Null Assertion',
}
counts = {}
total_methods = None
for r in rows:
    name = r['Syntactic Sugar'].strip()
    num = int(r['Java #'].replace(',', '').strip())
    if name == 'Total:':
        total_methods = num
    elif name in name_map:
        counts[name_map[name]] = num

order = ['String Interpolation', 'Elvis Operator', 'Getter/Setter Properties', 'Not-Null Assertion']

def pct(n, d):
    return (Decimal(n) * Decimal(100) / Decimal(d)).quantize(Decimal('0.000'), rounding=ROUND_HALF_UP)

lines = []
lines.append("### Table 2: Occurrences of desugared Kotlin syntactic sugars found in 2019/Java Boa dataset")
lines.append("")
lines.append("| Syntactic Sugar | Java Method # | Java Method % |")
lines.append("| :--- | :--- | :--- |")
for k in order:
    n = counts[k]
    p = pct(n, total_methods)
    lines.append(f"| {k} | {n:,} | {p}% |")
# Total row should be the dataset total and 100%
lines.append(f"| **Total:** | **{total_methods:,}** | **100%** |")

with open('/workspace/repro.txt', 'w', encoding='utf-8') as f:
    f.write("\n".join(lines) + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
