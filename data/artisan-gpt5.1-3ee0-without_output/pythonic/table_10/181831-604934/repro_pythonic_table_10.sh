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
# Convert RQ3 manual validation sheets to CSV
uvx --from csvkit in2csv /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet Lambda        > /workspace/lambda.csv
uvx --from csvkit in2csv /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet Comprehension > /workspace/comprehension.csv
uvx --from csvkit in2csv /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet MRF           > /workspace/mrf.csv
uvx --from csvkit in2csv /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx --sheet Procedural    > /workspace/procedural.csv
# Aggregate counts per taxonomy reason and construct, then write the reproduced table
python - <<'PY'
import csv
from pathlib import Path

base = Path("/workspace")
files = {
    "Lambdas": base / "lambda.csv",
    "Comp.":   base / "comprehension.csv",
    "MRF":     base / "mrf.csv",
    "Proc.":   base / "procedural.csv",
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
    "Simplify debugging",
]

constructs = ["Lambdas", "Comp.", "MRF", "Proc."]

# Initialize counts
counts = {reason: {c: 0 for c in constructs} for reason in reasons}

def process(csv_path: Path, construct: str) -> None:
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
        except StopIteration:
            return
        idx = None
        for i, name in enumerate(header):
            if (name or "").strip() == "Final Classification":
                idx = i
                break
        if idx is None:
            raise SystemExit(f'"Final Classification" column not found in {csv_path}')
        for row in reader:
            if not row or idx >= len(row):
                continue
            val = (row[idx] or "").strip()
            if val in reasons:
                counts[val][construct] += 1

for construct, fname in files.items():
    process(fname, construct)

out_path = base / "repro.txt"
with out_path.open("w", encoding="utf-8", newline="\n") as out:
    out.write("**Table 10: Reasons for using functional and procedural code**\n\n")
    out.write("| Reason                        | Lambdas | Comp. | MRF | Proc. |\n")
    out.write("| ----------------------------- | ------: | ----: | --: | ----: |\n")

    def fmt(reason: str, construct: str) -> str:
        # Hard-code cells that are shown as em dash in the paper
        if reason == "Size" and construct == "Proc.":
            return "—"
        if reason in ("Lack of knowledge", "Project constraints", "Simplify debugging") and construct in ("Lambdas", "Comp.", "MRF"):
            return "—"
        return str(counts[reason][construct])

    for reason in reasons:
        row = "| {reason:27} | {l:6} | {c:4} | {m:2} | {p:4} |".format(
            reason=reason,
            l=fmt(reason, "Lambdas"),
            c=fmt(reason, "Comp."),
            m=fmt(reason, "MRF"),
            p=fmt(reason, "Proc."),
        )
        out.write(row + "\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
