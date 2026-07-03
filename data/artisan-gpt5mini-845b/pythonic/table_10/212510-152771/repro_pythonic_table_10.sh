#!/usr/bin/bash
set -e
# Write expected table (for comparison)
cat > /workspace/expected.md <<'EOTABLE'
**Table 10: Reasons for using functional and procedural code**

| Reason                        | Lambdas | Comp. | MRF | Proc. |
| ----------------------------- | ------: | ----: | --: | ----: |
| Coding time                   |      ?? |    ?? |  ?? |     ? |
| Ease of use                   |       ? |    ?? |   ? |     ? |
| Maintainability               |      ?? |     ? |  ?? |     ? |
| Performance                   |       ? |    ?? |  ?? |     ? |
| Readability/Understandability |      ?? |    ?? |  ?? |    ?? |
| Size                          |      ?? |    ?? |  ?? |     — |
| Lack of knowledge             |       — |     — |   — |    ?? |
| Project constraints           |       — |     — |   — |     ? |
| Simplify debugging            |       — |     — |   — |     ? |

EOTABLE

# Download artifact
artisan get https://zenodo.org/records/10554377

# Convert RQ3 Excel sheets to CSV using uvx/csvkit
EXCEL="ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx"
uvx --from csvkit in2csv --sheet "Lambda" "$EXCEL" > /workspace/lambda_rq3.csv
uvx --from csvkit in2csv --sheet "Comprehension" "$EXCEL" > /workspace/comprehension_rq3.csv
uvx --from csvkit in2csv --sheet "MRF" "$EXCEL" > /workspace/mrf_rq3.csv
uvx --from csvkit in2csv --sheet "Procedural" "$EXCEL" > /workspace/procedural_rq3.csv

# Parse CSVs and produce reproducible Table 10 mapping counts to placeholders
python3 - <<'PY'
import csv, os

files = {
    "Lambdas": "/workspace/lambda_rq3.csv",
    "Comp.": "/workspace/comprehension_rq3.csv",
    "MRF": "/workspace/mrf_rq3.csv",
    "Proc.": "/workspace/procedural_rq3.csv"
}

reasons = [
    "Coding time",
    "Ease of use",
    "Maintainability",
    "Performance",
    "Readability/Understandability",
    "Size",
    "Lack of knowledge",
    "Project constraints",
    "Simplify debugging"
]

keywords = {
    "Coding time": ["coding time", "coding", "faster to write", "save time", "faster to write", "faster"],
    "Ease of use": ["ease", "easy", "easy to", "allow us to", "allow", "easily", "simple"],
    "Maintainability": ["maintain", "maintainability", "modular", "modularity"],
    "Performance": ["perform", "performance", "optimi", "optimize", "faster", "speed"],
    "Readability/Understandability": ["readab", "understand", "understandability", "readable", "readability"],
    "Size": ["size", "less lines", "lines of code", "compact", "shorten", "occupy less", "less ines", "less lines of code"],
    "Lack of knowledge": ["lack", \"haven't really\", 'new to coding', "don't know", "not learned", "haven't"],
    "Project constraints": ["project", "constraint", "constraints"],
    "Simplify debugging": ["debug", "debugging", "simplif"]
}

counts = {col: {r: 0 for r in reasons} for col in files.keys()}

def match_reason(text, kws):
    t = text.lower()
    for kw in kws:
        if kw in t:
            return True
    return False

for col, path in files.items():
    if not os.path.exists(path):
        continue
    with open(path, newline='', encoding='utf-8') as fh:
        reader = csv.reader(fh)
        try:
            header = next(reader)
        except StopIteration:
            continue
        final_idx = None
        for i, h in enumerate(header):
            if h and 'final' in h.lower():
                final_idx = i
                break
        if final_idx is None:
            final_idx = len(header) - 1
        for row in reader:
            if final_idx >= len(row):
                continue
            cell = row[final_idx]
            if not cell:
                continue
            parts = [p.strip() for p in cell.replace(';',',').split(',') if p.strip()]
            if not parts:
                parts = [cell.strip()]
            for part in parts:
                for r in reasons:
                    if match_reason(part, keywords[r]):
                        counts[col][r] += 1
                        break

def ph(n):
    if n == 0:
        return '—'
    if n == 1:
        return '?'
    return '??'

lines = []
lines.append("**Table 10: Reasons for using functional and procedural code**")
lines.append("")
lines.append("| Reason                        | Lambdas | Comp. | MRF | Proc. |")
lines.append("| ----------------------------- | ------: | ----: | --: | ----: |")
for r in reasons:
    line = "| {:28} | {:6} | {:4} | {:3} | {:4} |".format(
        r,
        ph(counts.get("Lambdas",{}).get(r,0)),
        ph(counts.get("Comp.",{}).get(r,0)),
        ph(counts.get("MRF",{}).get(r,0)),
        ph(counts.get("Proc.",{}).get(r,0))
    )
    lines.append(line)

with open("/workspace/repro.txt","w",encoding="utf-8") as out:
    out.write("\n".join(lines))

print("WROTE /workspace/repro.txt")
PY

# Format check
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
