#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -0.92, 1Q -0.89, Median -0.76, 3Q 1.12, Max 1.52

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 320, groups: User, 159

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
docker run --workdir /data -v${PWD}:/data --rm mdipenta/rexp:latest bash -lc "R --no-save < FuncConstructs-Statistics.r >/dev/null"
python - <<'PY'
import csv
from pathlib import Path

coeff_path = Path("results/Table-5-RQ1-mrf-coeff.txt")
rows = list(csv.DictReader(coeff_path.open()))
if not rows:
    raise SystemExit("No rows found in coefficient file")

pvals = [float(r["Pr(>|z|)"]) for r in rows]
m = len(pvals)

# Benjamini–Hochberg adjustment (R's p.adjust(..., "BH"))
order = sorted(range(m), key=lambda i: pvals[i])  # ascending p
q = [0.0] * m
for rank, idx in enumerate(order, start=1):
    q[idx] = pvals[idx] * m / rank
q = [min(1.0, v) for v in q]

min_so_far = 1.0
for idx in reversed(order):
    if q[idx] < min_so_far:
        min_so_far = q[idx]
    else:
        q[idx] = min_so_far

for i, r in enumerate(rows):
    r["Pr(>|z|)"] = repr(q[i])

with coeff_path.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
PY
cat results/Table-5-RQ1-mrf.txt results/Table-5-RQ1-mrf-coeff.txt > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
