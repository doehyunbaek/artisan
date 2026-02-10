#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o GILT_Artifacts.zip \
  https://zenodo.org/api/records/10461385/files/GILT_Artifacts.zip/content
unzip -o GILT_Artifacts.zip -d GILT_Artifacts

python3 - <<'PY'
import json

nb_path = "/workspace/GILT_Artifacts/GILT_Artifacts-main/study/analysis.ipynb"
r_script_path = "/workspace/analysis_exec.R"
data_dir = "/workspace/GILT_Artifacts/GILT_Artifacts-main/study"

with open(nb_path, "r", encoding="utf-8") as f:
    nb = json.load(f)

with open(r_script_path, "w", encoding="utf-8") as out:
    out.write(f"setwd('{data_dir}')\n")
    out.write("# Extracted code\n")
    for cell in nb.get("cells", []):
        if cell.get("cell_type") == "code":
            out.write("".join(cell.get("source", [])) + "\n\n")

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
from dataclasses import dataclass

TXT = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read()

@dataclass
class Model:
    coef: dict
    r2: float | None
    adj: float | None
    kind: str  # "lm" or "glm"

def stars(p: float) -> str:
    if p < 0.01: return "***"
    if p < 0.05: return "**"
    if p < 0.1:  return "*"
    return ""

def fmt_cell(est, se, p, *, add_stars: bool = True) -> str:
    if est is None or se is None or p is None:
        return ""
    s = stars(p) if add_stars else ""
    return f"{est:.2f}{s} ({se:.2f})"

def fmt_r2(x):
    return f"{x:.3f}" if x is not None else ""

def parse_coef_table(block: str) -> dict:
    out = {}
    m = re.search(
        r"(?s)Coefficients:\s*\n(.*?)(?:\n---|\n\n|Residual standard error:|\(Dispersion parameter|AIC:|\Z)",
        block
    )
    if not m:
        return out
    table = m.group(1).strip("\n")
    num_re = r"-?\d+(?:\.\d+)?(?:[eE]-?\d+)?"
    for line in table.splitlines():
        line = line.rstrip()
        if not line:
            continue
        if "Estimate" in line and "Std." in line:
            continue
        first_num = re.search(num_re, line)
        if not first_num:
            continue
        name = line[:first_num.start()].strip()
        nums = re.findall(num_re, line[first_num.start():])
        if len(nums) < 4:
            continue
        try:
            est = float(nums[0])
            se  = float(nums[1])
            p   = float(nums[3])
        except Exception:
            continue
        out[name] = (est, se, p)
    return out

def lm_r2(block: str):
    m = re.search(r"Multiple R-squared:\s*([0-9.]+)\s*,\s*Adjusted R-squared:\s*([\-0-9.]+)", block)
    if not m:
        return None, None
    return float(m.group(1)), float(m.group(2))

def glm_r2_from_block(block: str):
    # In this artifact output, each glm block contains two [1] lines (R2 then Adj R2)
    nums = re.findall(r"(?m)^\[1\]\s*([\-0-9.]+)\s*$", block)
    if len(nums) >= 2:
        return float(nums[-2]), float(nums[-1])
    return None, None

def extract_call_blocks(txt: str):
    starts = [m.start() for m in re.finditer(r"(?m)^Call:\s*$", txt)]
    blocks = []
    for i, s in enumerate(starts):
        e = starts[i + 1] if i + 1 < len(starts) else len(txt)
        blocks.append(txt[s:e])
    return blocks

def call_text(block: str) -> str:
    m = re.search(r"(?s)^Call:\s*\n(.*?)(?:\n\s*\n|\Z)", block)
    return (m.group(1) if m else "").strip()

blocks = extract_call_blocks(TXT)

m_time = Model({}, None, None, "lm")
m_under = Model({}, None, None, "glm")
progress_models = []

for b in blocks:
    ct = call_text(b).lower()

    if "lm(" in ct and "success_time_no_guess" in ct:
        coef = parse_coef_table(b)
        r2, adj = lm_r2(b)
        m_time = Model(coef, r2, adj, "lm")

    elif "glm(" in ct and "understanding" in ct:
        coef = parse_coef_table(b)
        r2, adj = glm_r2_from_block(b)
        m_under = Model(coef, r2, adj, "glm")

    elif "glm(" in ct and "progress_no_guess" in ct:
        coef = parse_coef_table(b)
        r2, adj = glm_r2_from_block(b)
        progress_models.append(Model(coef, r2, adj, "glm"))

m_prog_all = progress_models[0] if len(progress_models) > 0 else Model({}, None, None, "glm")
m_prog_pro = progress_models[1] if len(progress_models) > 1 else Model({}, None, None, "glm")
m_prog_stu = progress_models[2] if len(progress_models) > 2 else Model({}, None, None, "glm")

ROW_MAP = [
    ("Constant",            "(Intercept)"),
    ("Domain experience",   "experience"),
    ("Program. experience", "recruiting.years"),
    ("AI tool familiarity", "AI_experience"),
    ("Uses GILT",           "tool"),
]

COLS = [
    ("Progress (1)",         m_prog_all),
    ("Time (s) (2)",         m_time),
    ("Underst. (3)",         m_under),
    ("Progress (Pros)",      m_prog_pro),
    ("Progress (Students)",  m_prog_stu),
]

def get_cell(model: Model, coef_name: str) -> str:
    v = model.coef.get(coef_name)
    if not v:
        return ""
    est, se, p = v
    # expected: no stars for the lm (time) column
    add_stars = (model.kind != "lm")
    return fmt_cell(est, se, p, add_stars=add_stars)

print("**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**\n")
print("|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |")
print("| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |")

for row_label, coef_name in ROW_MAP:
    cells = [get_cell(m, coef_name) for _, m in COLS]
    print(
        f"| {row_label:<19} "
        f"| {cells[0]:>13} "
        f"| {cells[1]:>14} "
        f"| {cells[2]:>13} "
        f"| {cells[3]:>14} "
        f"| {cells[4]:>18} |"
    )

r2s  = [fmt_r2(m.r2)  for _, m in COLS]
adjs = [fmt_r2(m.adj) for _, m in COLS]
print(f"| {'*R*²':<19} | {r2s[0]:>13} | {r2s[1]:>14} | {r2s[2]:>13} | {r2s[3]:>14} | {r2s[4]:>18} |")
print(f"| {'Adj. *R*²':<19} | {adjs[0]:>13} | {adjs[1]:>14} | {adjs[2]:>13} | {adjs[3]:>14} | {adjs[4]:>18} |")

print("\n*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*")
print()  # newline at EOF
PY
echo '</artisan_submit>'

