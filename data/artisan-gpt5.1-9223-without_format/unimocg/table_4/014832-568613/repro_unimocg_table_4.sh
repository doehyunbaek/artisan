#!/usr/bin/bash
set -e

# Work from /workspace for predictable paths
cd /workspace

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Field Immutability Results for OpenJDK**

| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |
| ---------- | ------: | -----------: | -------: | -------: |
| Ad-hoc CHA |  ?? ??? |       ?? ??? |      ??? |   ?? ??? |
| CHA        |  ?? ??? |       ?? ??? |       ?? |   ?? ??? |
| RTA        |  ?? ??? |        ? ??? |      ??? |   ?? ??? |
| XTA        |  ?? ??? |        ? ??? |      ??? |   ?? ??? |

*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011

# Section 3: Reproduction commands
# Make the path expected by aggregate_opal_immutability.py available
mkdir -p /evaluation/results
if [ ! -e /evaluation/results/immutability ]; then
    ln -s /workspace/Unimocg_Artifact/evaluation/results/immutability /evaluation/results/immutability
fi

# Regenerate the immutability summary from the raw results
python3 /workspace/Unimocg_Artifact/docker/runner/aggregate_opal_immutability.py > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
python3 - << 'PY'
import re
from pathlib import Path

text = Path("/workspace/repro.txt").read_text()

pattern = re.compile(
    r"algorithm:\s+(\S+).*?"
    r"Mutable Fields:\s+(\d+).*?"
    r"Non Transitively Immutable Fields:\s+(\d+).*?"
    r"Dependently Immutable Fields:\s+(\d+).*?"
    r"Transitively Immutable Fields:\s+(\d+)",
    re.S,
)

data = {}
for name, mutable, nontrans, depen, trans in pattern.findall(text):
    data[name] = (int(mutable), int(nontrans), int(depen), int(trans))

rows = [
    ("Ad-hoc CHA", "AdHocCHA"),
    ("CHA", "CHA"),
    ("RTA", "RTA"),
    ("XTA", "XTA"),
]

def fmt(x: int) -> str:
    # Format with space as thousands separator, e.g., 23195 -> "23 195"
    return f"{x:,}".replace(",", " ")

print("**Table 4: Field Immutability Results for OpenJDK**\n")
print("| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |")
print("| ---------- | ------: | -----------: | -------: | -------: |")
for label, key in rows:
    m, nt, dep, tr = data[key]
    print(f"| {label} | {fmt(m):7s} | {fmt(nt):11s} | {dep:7d} | {fmt(tr):7s} |")
print("\n*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*")
PY
echo '</artisan_submit>'
