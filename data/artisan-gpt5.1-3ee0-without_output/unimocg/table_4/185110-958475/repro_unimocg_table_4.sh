#!/usr/bin/bash
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
# Section 3: Reproduction commands – recompute counts from raw immutability results
python3 - <<'PY'
import pathlib
from collections import Counter

base = pathlib.Path("Unimocg_Artifact/evaluation/results/immutability")

# Map suffixes in the per-field lines to the four categories
markers = {
    "Mutable Field": "mutable",
    "Non Transitively Immutable Field": "non_trans",
    "Dependently Immutable Field": "depen",
    "Transitively Immutable Field": "trans",
}

results = {}

for alg_dir in sorted(base.iterdir()):
    if not alg_dir.is_dir():
        continue
    alg = alg_dir.name
    counts = Counter()
    for txt in alg_dir.glob("*.txt"):
        with txt.open("r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if " | " not in line:
                    continue
                for marker, key in markers.items():
                    if marker in line:
                        counts[key] += 1
                        break
    results[alg] = counts

def fmt(n: int) -> str:
    s = str(n)
    return s if len(s) <= 3 else s[:-3] + " " + s[-3:]

order = [
    ("AdHocCHA", "Ad-hoc CHA"),
    ("CHA", "CHA"),
    ("RTA", "RTA"),
    ("XTA", "XTA"),
]

out_path = pathlib.Path("/workspace/repro.txt")
with out_path.open("w", encoding="utf-8") as out:
    out.write("**Table 4: Field Immutability Results for OpenJDK**\n\n")
    out.write("| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |\n")
    out.write("| ---------- | ------: | -----------: | -------: | -------: |\n")
    for key, label in order:
        c = results[key]
        out.write(
            f"| {label} | {fmt(c['mutable'])} | {fmt(c['non_trans'])} | "
            f"{fmt(c['depen'])} | {fmt(c['trans'])} |\n"
        )
    out.write(
        "\n*depen. = dependently immutable, trans. = transitively immutable. "
        "Higher numbers in columns to the right = more precise.*\n"
    )
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
