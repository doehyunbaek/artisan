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
# Section 3: Reproduction commands (parse the summary file using Python)
SUMFILE="Unimocg_Artifact/summaries/immutability_results.txt"
python3 - <<'PY'
import re
d = {}
alg = None
with open("Unimocg_Artifact/summaries/immutability_results.txt", "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        m = re.match(r'^algorithm:\s*(\S+)', line)
        if m:
            alg = m.group(1)
            d[alg] = [None, None, None, None]
            continue
        if 'Mutable Fields' in line:
            num = re.search(r'(\d+)', line)
            if num: d[alg][0] = num.group(1)
        if 'Non Transitively Immutable Fields' in line:
            num = re.search(r'(\d+)', line)
            if num: d[alg][1] = num.group(1)
        if 'Dependently Immutable Fields' in line:
            num = re.search(r'(\d+)', line)
            if num: d[alg][2] = num.group(1)
        if 'Transitively Immutable Fields' in line:
            num = re.search(r'(\d+)', line)
            if num: d[alg][3] = num.group(1)
# Write repro.txt with the expected ordering and plain integers
order = [("AdHocCHA","Ad-hoc CHA"), ("CHA","CHA"), ("RTA","RTA"), ("XTA","XTA")]
with open("/workspace/repro.txt", "w") as out:
    out.write("**Table 4: Field Immutability Results for OpenJDK**\n\n")
    out.write("| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |\n")
    out.write("| ---------- | ------: | -----------: | -------: | -------: |\n")
    for key,label in order:
        vals = d.get(key, ["","","",""])
        out.write(f"| {label} | {vals[0]} | {vals[1]} | {vals[2]} | {vals[3]} |\n")
    out.write("\n*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
