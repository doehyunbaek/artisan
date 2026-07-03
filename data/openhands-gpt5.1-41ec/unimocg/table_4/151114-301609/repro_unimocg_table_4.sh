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
cd /workspace
if [ ! -f Unimocg_Artifact.zip ]; then
  curl -L "https://zenodo.org/api/records/10890011/files/Unimocg_Artifact.zip/content" -o Unimocg_Artifact.zip
fi
if [ ! -d docker ] || [ ! -d evaluation ]; then
  unzip -o Unimocg_Artifact.zip
fi
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace
if [ ! -e /evaluation ]; then
  ln -s /workspace/evaluation /evaluation
fi
python3 docker/runner/aggregate_opal_immutability.py > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 - << 'EOPY'
import pathlib
import re

text = pathlib.Path('/workspace/repro.txt').read_text(encoding='utf-8')
blocks = re.split(r'-{10,}', text)
data = {}
for block in blocks:
    block = block.strip()
    if not block:
        continue
    m_alg = re.search(r'algorithm:\s*(\S+)', block)
    if not m_alg:
        continue
    alg = m_alg.group(1)
    m_mut = re.search(r'Mutable Fields:\s*(\d+)', block)
    m_nt = re.search(r'^\s*Non Transitively Immutable Fields:\s*(\d+)', block, re.MULTILINE)
    m_dep = re.search(r'Dependently Immutable Fields:\s*(\d+)', block)
    m_tr = re.search(r'^\s*Transitively Immutable Fields:\s*(\d+)', block, re.MULTILINE)
    data[alg] = (
        int(m_mut.group(1)),
        int(m_nt.group(1)),
        int(m_dep.group(1)),
        int(m_tr.group(1)),
    )

order = [
    ("Ad-hoc CHA", "AdHocCHA"),
    ("CHA", "CHA"),
    ("RTA", "RTA"),
    ("XTA", "XTA"),
]

def fmt(n: int) -> str:
    # Format with thin thousands separator (space) and right-align
    return f"{n:,}".replace(",", " ").rjust(7)

print("**Table 4: Field Immutability Results for OpenJDK**\n")
print("| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |")
print("| ---------- | ------: | -----------: | -------: | -------: |")
for label, key in order:
    m, nt, dep, tr = data[key]
    print(f"| {label:<10} | {fmt(m)} | {fmt(nt)} | {fmt(dep)} | {fmt(tr)} |")
print("\n*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*")
EOPY
echo '</artisan_submit>'
