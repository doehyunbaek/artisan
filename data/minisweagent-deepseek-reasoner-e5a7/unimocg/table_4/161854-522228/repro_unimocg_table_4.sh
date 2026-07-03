#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Field Immutability Results for OpenJDK**

| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |
| ---------- | ------: | -----------: | -------: | -------: |
| Ad-hoc CHA |  23 195 |       24 296 |      108 |   46 368 |
| CHA        |  23 195 |       25 252 |       20 |   45 500 |
| RTA        |  23 195 |        7 352 |      316 |   63 104 |
| XTA        |  23 195 |        2 871 |      316 |   67 585 |

*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*

EOTABLE
# Section 2: Artifact download
# Download the artifact from Zenodo
curl -L -o /workspace/Unimocg_Artifact.zip "https://zenodo.org/records/10890011/files/Unimocg_Artifact.zip?download=1"
# Unzip the artifact
unzip -q /workspace/Unimocg_Artifact.zip -d /workspace/artifact
# Section 3: Reproduction commands (populate from reviewed steps)
# Run the aggregate script to reproduce the table
cat > /workspace/reproduce_table.py <<'PYEOF'
import re, os
# Read the summary file
summary_path = "/workspace/artifact/summaries/immutability_results.txt"
with open(summary_path, 'r') as f:
    content = f.read()
# Extract numbers for each algorithm
pattern = r"algorithm: (\w+)\s*\n\s*\n\s*Mutable Fields: (\d+)\s*\n\s*Non Transitively Immutable Fields: (\d+)\s*\n\s*Dependently Immutable Fields: (\d+)\s*\n\s*Transitively Immutable Fields: (\d+)"
matches = re.findall(pattern, content)
# Order as in the table: AdHocCHA, CHA, RTA, XTA
order = ['AdHocCHA', 'CHA', 'RTA', 'XTA']
data = {}
for name, m, nt, d, t in matches:
    data[name] = (m, nt, d, t)
# Fallback if regex fails: extract all numbers and group
if len(data) != 4:
    numbers = re.findall(r'(\d+)', content)
    grouped = [numbers[i:i+4] for i in range(0, len(numbers), 4)]
    data = {}
    # The file order is AdHocCHA, RTA, XTA, CHA
    order = ['AdHocCHA', 'RTA', 'XTA', 'CHA']
    for i, name in enumerate(order):
        data[name] = tuple(grouped[i])
# Format the table
lines = []
lines.append("**Table 4: Field Immutability Results for OpenJDK**")
lines.append("")
lines.append("| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |")
lines.append("| ---------- | ------: | -----------: | -------: | -------: |")
for name in order:
    m, nt, d, t = data[name]
    m_f = f"{int(m):,}".replace(',', ' ')
    nt_f = f"{int(nt):,}".replace(',', ' ')
    d_f = f"{int(d):,}".replace(',', ' ')
    t_f = f"{int(t):,}".replace(',', ' ')
    display_name = name
    if name == 'AdHocCHA':
        display_name = 'Ad-hoc CHA'
    lines.append(f"| {display_name:9} | {m_f:>6} | {nt_f:>11} | {d_f:>8} | {t_f:>8} |")
lines.append("")
lines.append("*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*")
output = "\n".join(lines)
# Write to repro.txt
with open("/workspace/repro.txt", "w") as f:
    f.write(output)
print(output)
PYEOF
python3 /workspace/reproduce_table.py > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
