#!/usr/bin/bash
# Section 1: Expected table
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
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
ROOT="ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts"
RQ3_XLSX="$ROOT/working-results/RQ3ManualValidation.xlsx"

# Convert each RQ3 sheet to CSV
uvx --from csvkit in2csv --sheet Lambda "$RQ3_XLSX" > /workspace/lambda.csv
uvx --from csvkit in2csv --sheet Comprehension "$RQ3_XLSX" > /workspace/comprehension.csv
uvx --from csvkit in2csv --sheet MRF "$RQ3_XLSX" > /workspace/mrf.csv
uvx --from csvkit in2csv --sheet Procedural "$RQ3_XLSX" > /workspace/procedural.csv

# Aggregate coded reasons and emit the reproduced Table 10 as Markdown
python - << 'PY'
import csv
from collections import Counter
from pathlib import Path

base = Path("/workspace")
files = {
    "Lambdas": base / "lambda.csv",
    "Comp.": base / "comprehension.csv",
    "MRF": base / "mrf.csv",
    "Proc.": base / "procedural.csv",
}

canonical_map = {
    "coding time": "Coding time",
    "ease of use": "Ease of use",
    "maintainability": "Maintainability",
    "performance": "Performance",
    "readability/understandability": "Readability/Understandability",
    "size": "Size",
    "lack of knowledge": "Lack of knowledge",
    "project constraints": "Project constraints",
    "debugging is easier": "Simplify debugging",
}

reasons_order = [
    "Coding time",
    "Ease of use",
    "Maintainability",
    "Performance",
    "Readability/Understandability",
    "Size",
    "Lack of knowledge",
    "Project constraints",
    "Simplify debugging",
]

results = {}

for label, path in files.items():
    counts = Counter()
    with path.open(newline='', encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        for row in reader:
            if not any(cell.strip() for cell in row):
                continue
            # Codes start at column index 4 ("Final Classification" and any extra coding columns)
            for cell in row[4:]:
                v = cell.strip()
                if not v:
                    continue
                key = v.lower()
                canon = canonical_map.get(key)
                if canon:
                    counts[canon] += 1
    results[label] = counts

lines = []
lines.append("**Table 10: Reasons for using functional and procedural code**")
lines.append("")
lines.append("| Reason                        | Lambdas | Comp. | MRF | Proc. |")
lines.append("| ----------------------------- | ------: | ----: | --: | ----: |")

for reason in reasons_order:
    # Determine display values, applying “—” where a reason is specific to one side
    vals = {}
    for col in ["Lambdas", "Comp.", "MRF", "Proc."]:
        is_functional = col in ("Lambdas", "Comp.", "MRF")
        if reason == "Size" and col == "Proc.":
            val = "—"
        elif reason in ("Lack of knowledge", "Project constraints", "Simplify debugging") and is_functional:
            val = "—"
        else:
            val = str(results[col].get(reason, 0))
        vals[col] = val
    lines.append(
        "| {reason:<27} | {l:>6} | {c:>4} | {m:>2} | {p:>4} |".format(
            reason=reason,
            l=vals["Lambdas"],
            c=vals["Comp."],
            m=vals["MRF"],
            p=vals["Proc."],
        )
    )

(base / "repro.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
