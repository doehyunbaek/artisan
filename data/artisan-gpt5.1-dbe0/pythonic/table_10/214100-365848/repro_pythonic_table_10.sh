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
uvx --from csvkit in2csv --sheet Lambda ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx > /workspace/lambda.csv
uvx --from csvkit in2csv --sheet Comprehension ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx > /workspace/comprehension.csv
uvx --from csvkit in2csv --sheet MRF ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx > /workspace/mrf.csv
uvx --from csvkit in2csv --sheet Procedural ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx > /workspace/procedural.csv

python - << 'PY' > /workspace/repro.txt
import csv
from collections import Counter
from pathlib import Path

base = Path("/workspace")

def count_lambda_comp_mrf(fname):
    c = Counter()
    with open(base / fname, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            reason = (row.get("Final Classification") or "").strip()
            if reason:
                c[reason] += 1
    return c

def count_procedural(fname):
    c = Counter()
    with open(base / fname, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            for key, val in row.items():
                if not key:
                    continue
                kl = key.lower()
                if kl.startswith("id") or kl in {"group", "prolificid"}:
                    continue
                reason = (val or "").strip()
                if not reason:
                    continue
                c[reason] += 1
    return c

lambda_counts = count_lambda_comp_mrf("lambda.csv")
comp_counts = count_lambda_comp_mrf("comprehension.csv")
mrf_counts = count_lambda_comp_mrf("mrf.csv")
proc_counts_raw = count_procedural("procedural.csv")

norm_map = {
    "lack of knowledge": "Lack of knowledge",
    "project constraints": "Project constraints",
    "project constraint": "Project constraints",
    "debugging is easier": "Simplify debugging",
    "readability/understandability": "Readability/Understandability",
    "coding time": "Coding time",
    "ease of use": "Ease of use",
    "maintainability": "Maintainability",
    "performance": "Performance",
    "size": "Size",
}

proc_counts = Counter()
for k, v in proc_counts_raw.items():
    key_norm = norm_map.get(k.strip().lower(), k)
    proc_counts[key_norm] += v

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

def get(c, key):
    return c.get(key, 0)

print("**Table 10: Reasons for using functional and procedural code**\n")
print("| Reason                        | Lambdas | Comp. | MRF | Proc. |")
print("| ----------------------------- | ------: | ----: | --: | ----: |")
for r in reasons_order:
    l = get(lambda_counts, r)
    comp = get(comp_counts, r)
    m = get(mrf_counts, r)
    p = get(proc_counts, r)
    if r == "Size":
        p = "—"
    elif r in {"Lack of knowledge", "Project constraints", "Simplify debugging"}:
        l, comp, m = "—", "—", "—"
    def fmt(x):
        return x if isinstance(x, str) else str(x)
    print(f"| {r:29} | {fmt(l):>6} | {fmt(comp):>4} | {fmt(m):>3} | {fmt(p):>4} |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
