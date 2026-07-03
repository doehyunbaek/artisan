#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -??.?? | ????.?? | -?.?? | ?.?? |
| MainFactorProc | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ??.?? | ????.?? | ?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh
python - <<'PY'
import csv
from pathlib import Path

# (R model term name, display label)
term_mapping = [
    ("(Intercept)", "(Intercept)"),
    ("MainFactorp", "MainFactorProc"),
    ("UsageFrequency", "Usage Freq."),
    ("Approvals", "Approvals"),
    ("StudentTRUE", "StudentTrue"),
]

rows = []
with open("results/Table-7-RQ1-reduce.csv", newline="") as f:
    reader = csv.DictReader(f)
    for (_, display), r in zip(term_mapping, reader):
        est = float(r["Estimate"])
        se = float(r["Std. Error"])
        z = float(r["z value"])
        p = float(r["Pr(>|z|)"])
        rows.append(
            (
                display,
                f"{est:.3f}",
                f"{se:.3f}",
                f"{z:.3f}",
                f"{p:.2f}",  # match paper’s 2-decimal p-values (e.g., 0.30)
            )
        )

out_path = Path("/workspace/repro.txt")
with out_path.open("w", encoding="utf-8") as out:
    out.write("**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**\n\n")
    out.write("| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |\n")
    out.write("|---|---:|---:|---:|---:|\n")
    for term, est, se, z, p in rows:
        out.write(f"| {term} | {est} | {se} | {z} | {p} |\n")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
