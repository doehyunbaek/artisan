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
# Convert RQ3ManualValidation.xlsx sheets to CSV files
uvx --from csvkit in2csv ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet Lambda        > /workspace/lambda.csv
uvx --from csvkit in2csv ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet Comprehension > /workspace/comprehension.csv
uvx --from csvkit in2csv ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet MRF          > /workspace/mrf.csv
uvx --from csvkit in2csv ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet Procedural   > /workspace/procedural.csv

# Compute Table 10 values (per-participant COUNTS) and write /workspace/repro.txt as a markdown table
python - <<'PY'
import csv
from collections import defaultdict

# Canonical reasons in the order of Table 10
REASONS = [
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

CONSTRUCT_FILES = {
    "Lambdas": "/workspace/lambda.csv",
    "Comp.":   "/workspace/comprehension.csv",
    "MRF":     "/workspace/mrf.csv",
    "Proc.":   "/workspace/procedural.csv",
}

def canonical_reason(label: str):
    s = (label or "").strip()
    if not s:
        return None
    low = s.lower()
    # Procedural-specific / negative reasons
    if "debug" in low:
        return "Simplify debugging"
    if "project constraint" in low:
        return "Project constraints"
    if "lack of knowledge" in low:
        return "Lack of knowledge"
    # Shared reasons
    if "coding time" in low:
        return "Coding time"
    if "ease of use" in low:
        return "Ease of use"
    if "maintain" in low:
        return "Maintainability"
    if "perform" in low:
        return "Performance"
    if "size" in low:
        return "Size"
    if ("readability/understandability" in low
        or "readability" in low
        or "understandability" in low):
        return "Readability/Understandability"
    # Anything else is outside the Table 10 taxonomy
    return None

def aggregate_construct_per_participant(path: str):
    """
    Return counts_per_reason where each participant is counted
    at most once per reason.
    """
    reasons_per_participant = defaultdict(set)
    with open(path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            pid = (row.get("ID") or "").strip()
            if not pid:
                continue
            canon = canonical_reason(row.get("Final Classification") or "")
            if not canon:
                continue
            reasons_per_participant[pid].add(canon)
    counts = {r: 0 for r in REASONS}
    for pid, rset in reasons_per_participant.items():
        for r in rset:
            if r in counts:
                counts[r] += 1
    return counts

# Compute per-construct counts
counts = {}
for cname, path in CONSTRUCT_FILES.items():
    counts[cname] = aggregate_construct_per_participant(path)

lines = []
lines.append("**Table 10: Reasons for using functional and procedural code**\n")
lines.append("\n")
lines.append("| Reason                        | Lambdas | Comp. | MRF | Proc. |\n")
lines.append("| ----------------------------- | ------: | ----: | --: | ----: |\n")

for reason in REASONS:
    lv = counts["Lambdas"].get(reason, 0)
    cv = counts["Comp."].get(reason, 0)
    mv = counts["MRF"].get(reason, 0)
    pv = counts["Proc."].get(reason, 0)

    def cell(val):
        return "—" if val == 0 else str(val)

    # For Size/Proc. we still want '—' even if val==0, which cell() already does
    lines.append(
        f"| {reason:<27} | {cell(lv):>6} | {cell(cv):>4} | {cell(mv):>3} | {cell(pv):>4} |\n"
    )

with open("/workspace/repro.txt", "w", encoding="utf-8") as out:
    out.writelines(lines)
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
