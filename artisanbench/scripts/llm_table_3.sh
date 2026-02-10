#!/usr/bin/env bash
set -euo pipefail

curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o GILT_Artifacts.zip \
  https://zenodo.org/api/records/10461385/files/GILT_Artifacts.zip/content

unzip -q GILT_Artifacts.zip -d GILT_Artifacts

python3 - <<'PY'
import json

nb_path = '/workspace/GILT_Artifacts/GILT_Artifacts-main/study/analysis.ipynb'
r_script_path = '/workspace/analysis_exec.R'
data_dir = '/workspace/GILT_Artifacts/GILT_Artifacts-main/study'

with open(nb_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

with open(r_script_path, 'w', encoding='utf-8') as out:
    out.write(f"setwd('{data_dir}')\n")
    out.write("# Extracted code\n")
    for cell in nb.get('cells', []):
        if cell.get('cell_type') == 'code':
            source = ''.join(cell.get('source', []))
            out.write(source + "\n\n")

print(f"Created {r_script_path}")
PY

cp /workspace/GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv \
   /workspace/GILT_Artifacts/GILT_Artifacts-main/study/ase_data.csv

docker run --rm \
  -v /workspace:/workspace \
  rocker/verse:4.3.1 \
  /bin/bash -lc "
    install2.r --error --skipinstalled lme4 lmerTest MuMIn car rsq parameters plyr reshape2 gridExtra
    Rscript /workspace/analysis_exec.R > /workspace/repro.txt 2>&1
  "

echo '<artisan_submit>'
python3 - <<'PY'
import re

txt = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read()

# We ONLY want these three GLM blocks (not the earlier lm()).
MODELS = [
    ("Prompt (1)",   "query_total"),
    ("Followup (2)", "Query_followup"),
    ("All (3)",      "usage_total"),
]

ROWS = [
    ("Constant",            "(Intercept)"),
    ("AI tool familiarity", "AI_experience"),
    ("Information Comprh.", "info_style"),
    ("Learning Process",    "learning_style"),
]

def stars(p: float) -> str:
    if p < 0.01: return "***"
    if p < 0.05: return "**"
    if p < 0.1:  return "*"
    return ""

def extract_glm_block(outcome: str) -> str:
    # Match EXACTLY the glm call for that outcome, then include until next "Call:" or EOF.
    m = re.search(
        rf"(?s)Call:\s*\n"
        rf"glm\(formula\s*=\s*{re.escape(outcome)}\s*~.*?"
        rf"(?=\nCall:\s*\n|\Z)",
        txt
    )
    if not m:
        raise SystemExit(f"ERROR: could not find glm block for {outcome}")
    return m.group(0)

def parse_coeffs(block: str):
    # Pull lines between "Coefficients:" and the '---' marker.
    m = re.search(r"(?s)Coefficients:\s*\n(.*?)(?:\n---\n|\Z)", block)
    if not m:
        raise SystemExit("ERROR: coefficients section not found")
    sec = m.group(1)

    # Parse coefficient lines:
    # term  Estimate  Std. Error  t value  Pr(>|t|)
    parsed = {}
    for line in sec.splitlines():
        if not line.strip():
            continue
        # skip header line
        if "Estimate" in line and "Std." in line and ("Pr(>|" in line or "Pr(>" in line):
            continue

        # (Intercept)     1.38541    0.31008   4.468 0.000119 ***
        mm = re.match(
            r"^\s*(\S+)\s+(-?\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+([0-9.]+(?:e-?\d+)?)",
            line,
            flags=re.I,
        )
        if not mm:
            continue

        term = mm.group(1)
        est = float(mm.group(2))
        se  = float(mm.group(3))
        p   = float(mm.group(5))
        parsed[term] = (est, se, p)

    return parsed

def extract_r2_adj(block: str):
    # In this notebook, rsq prints two lines like:
    # [1] 0.2625566
    # [1] 0.1835449
    nums = [float(x) for x in re.findall(r"(?m)^\[1\]\s*([0-9.]+)\s*$", block)]
    if len(nums) >= 2:
        return nums[-2], nums[-1]
    raise SystemExit("ERROR: missing R^2 prints")

cols = {}
for col_name, outcome in MODELS:
    blk = extract_glm_block(outcome)
    coefs = parse_coeffs(blk)

    vals = {}
    for label, term in ROWS:
        if term not in coefs:
            raise SystemExit(f"ERROR: term {term} missing in {outcome}")
        est, se, p = coefs[term]
        vals[label] = f"{est:.2f}{stars(p)} ({se:.2f})"

    r2, adj = extract_r2_adj(blk)
    vals["*R*²"] = f"{r2:.3f}"
    vals["Adj. *R*²"] = f"{adj:.3f}"
    cols[col_name] = vals

# Emit expected markdown
print("**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**\n")
print("|                     |     Prompt (1) |  Followup (2) |        All (3) |")
print("| ------------------- | -------------: | ------------: | -------------: |")

def row_line(lbl: str) -> str:
    return (
        f"| {lbl:<19} | "
        f"{cols['Prompt (1)'][lbl]:>13} | "
        f"{cols['Followup (2)'][lbl]:>12} | "
        f"{cols['All (3)'][lbl]:>13} |"
    )

for lbl, _ in ROWS:
    print(row_line(lbl))
print(row_line("*R*²"))
print(row_line("Adj. *R*²"))
print("\n*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*")
PY
echo '</artisan_submit>'
