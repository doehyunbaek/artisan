#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o Unimocg_Artifact.zip https://zenodo.org/api/records/10890011/files/Unimocg_Artifact.zip/content
unzip Unimocg_Artifact.zip -d Unimocg_Artifact
mkdir -p /evaluation/results
if [ ! -e /evaluation/results/immutability ]; then
    ln -s /workspace/Unimocg_Artifact/evaluation/results/immutability /evaluation/results/immutability
fi

python3 /workspace/Unimocg_Artifact/docker/runner/aggregate_opal_immutability.py > /workspace/repro.txt
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
