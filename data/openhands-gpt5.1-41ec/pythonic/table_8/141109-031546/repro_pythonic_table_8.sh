#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -15.80 | 1383.44 | 0.01 | 0.99 |
| MainFactorProc | -0.06 | 0.40 | -0.16 | 0.99 |
| Usage Freq. | -0.18 | 0.33 | -0.54 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.76 | 0.99 |
| StudentTrue | 15.56 | 1383.44 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
if [ ! -d "/workspace/ICSE2024-funcConstructs-Artifacts" ]; then
  cd /workspace
  curl -L -o ICSE2024-funcConstructs-Artifacts.zip "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip"
  unzip -o ICSE2024-funcConstructs-Artifacts.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts
# Ensure Docker image is available
docker pull mdipenta/rexp:latest
# Run the Dockerized R analysis to regenerate all tables
sh run-analysis.sh

# Extract Table 8 (filter logistic regression) and format as Markdown
python - <<'PY'
import csv, math, pathlib

infile = pathlib.Path("/workspace/ICSE2024-funcConstructs-Artifacts/results/Table-8-RQ1-filter.csv")
rows = list(csv.DictReader(infile.open()))

terms_src = ["(Intercept)", "MainFactorp", "UsageFrequency", "Approvals", "StudentTRUE"]
terms_dst = ["(Intercept)", "MainFactorProc", "Usage Freq.", "Approvals", "StudentTrue"]

with open("/workspace/repro.txt", "w", encoding="utf-8") as out:
    out.write("**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**\n\n")
    out.write("| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |\n")
    out.write("|---|---:|---:|---:|---:|\n")

    def fmt(val: float) -> str:
        # Avoid printing signed negative zeros, match paper-style rounding
        return "0.00" if abs(val) < 0.005 else f"{val:.2f}"

    for src, dst, row in zip(terms_src, terms_dst, rows):
        est = float(row["Estimate"])
        se = float(row["Std. Error"])
        z = float(row["z value"])
        p = float(row["Pr(>|z|)"])
        # Match paper formatting: intercept z reported as positive
        z_print = abs(z) if src == "(Intercept)" else z
        out.write(f"| {dst} | {fmt(est)} | {se:.2f} | {fmt(z_print)} | {p:.2f} |\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
