#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**

|                     |     Prompt (1) |  Followup (2) |        All (3) |
| ------------------- | -------------: | ------------: | -------------: |
| Constant            | 1.39*** (0.31) | -0.82 (0.69)  | 2.43*** (0.27) |
| AI tool familiarity |  0.19** (0.07) | 0.38** (0.15) |   0.11 (0.06)  |
| Information Comprh. |  -0.04 (0.15)  |  0.44 (0.30)  |  -0.04 (0.13)  |
| Learning Process    |   0.19 (0.14)  | 0.60** (0.29) |  -0.12 (0.13)  |
| *R*²                |         0.263  |        0.283  |         0.165  |
| Adj. *R*²           |         0.184  |        0.206  |         0.075  |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10461385

# Section 3: Reproduction commands (populate from reviewed steps)
# Parse the executed R notebook to reconstruct the regression table and write it to /workspace/repro.txt
python - << 'PY'
import json, pathlib, re

nb_path = pathlib.Path("GILT_Artifacts/GILT_Artifacts-main/study/analysis.ipynb")
nb = json.loads(nb_path.read_text())
cells = nb["cells"]

# Locate the three glm models corresponding to Prompt, Followup, and All usage
models = {
    "Prompt":   {"marker": "glm(query_total ~"},
    "Followup": {"marker": "glm(Query_followup~"},
    "All":      {"marker": "glm(usage_total ~"},
}

for name, m in models.items():
    for i, cell in enumerate(cells):
        if cell.get("cell_type") != "code":
            continue
        src = "".join(cell.get("source", []))
        if m["marker"] in src:
            m["cell_index"] = i
            break

coef_pattern = re.compile(
    r"\s*(\([^)]+\)|AI_experience|info_style|learning_style)\s+"
    r"([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s+"
    r"([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s+"
    r"([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s+"
    r"([0-9.eE+-]+)"
)

def extract_coeffs_and_p(text):
    coefs = {}
    for line in text.splitlines():
        m = coef_pattern.match(line)
        if not m:
            continue
        var = m.group(1)
        est = float(m.group(2))
        se = float(m.group(3))
        p_str = m.group(5)
        try:
            pval = float(p_str)
        except ValueError:
            continue
        coefs[var] = (est, se, pval)
    return coefs

def extract_rsq(cell):
    vals = []
    for out in cell.get("outputs", []):
        data = out.get("data", {})
        txt = None
        if "text/plain" in data:
            t = data["text/plain"]
            txt = "\n".join(t) if isinstance(t, list) else str(t)
        if not txt:
            continue
        for line in txt.splitlines():
            line = line.strip()
            m = re.match(r"\[1\]\s+([0-9.]+)", line)
            if m:
                vals.append(float(m.group(1)))
    if len(vals) < 2:
        return None, None
    return vals[0], vals[1]

results = {}
for name, m in models.items():
    ci = m["cell_index"]
    # Coefficients come from the summary() output (text/plain)
    coef_txt = ""
    for out in cells[ci].get("outputs", []):
        data = out.get("data", {})
        if "text/plain" in data:
            t = data["text/plain"]
            coef_txt = "\n".join(t) if isinstance(t, list) else str(t)
            break
    coefs = extract_coeffs_and_p(coef_txt)
    r2, r2adj = extract_rsq(cells[ci+1])

    def fmt_coef(var_label, var_key):
        est, se, pval = coefs[var_key]
        # significance stars
        if pval < 0.01:
            stars = "***"
        elif pval < 0.05:
            stars = "**"
        elif pval < 0.1:
            stars = "*"
        else:
            stars = ""
        return f"{est:.2f}{stars} ({se:.2f})"

    results[name] = {
        "Constant": fmt_coef("Constant", "(Intercept)"),
        "AI tool familiarity": fmt_coef("AI tool familiarity", "AI_experience"),
        "Information Comprh.": fmt_coef("Information Comprh.", "info_style"),
        "Learning Process": fmt_coef("Learning Process", "learning_style"),
        "R2": f"{r2:.3f}",
        "AdjR2": f"{r2adj:.3f}",
    }

# Build markdown table in the same format as expected.md
lines = []
lines.append("**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**")
lines.append("")
lines.append("|                     |     Prompt (1) |  Followup (2) |        All (3) |")
lines.append("| ------------------- | -------------: | ------------: | -------------: |")
lines.append(f"| Constant            | {results['Prompt']['Constant']} | {results['Followup']['Constant']} | {results['All']['Constant']} |")
lines.append(f"| AI tool familiarity | {results['Prompt']['AI tool familiarity']} | {results['Followup']['AI tool familiarity']} | {results['All']['AI tool familiarity']} |")
lines.append(f"| Information Comprh. | {results['Prompt']['Information Comprh.']} | {results['Followup']['Information Comprh.']} | {results['All']['Information Comprh.']} |")
lines.append(f"| Learning Process    | {results['Prompt']['Learning Process']} | {results['Followup']['Learning Process']} | {results['All']['Learning Process']} |")
lines.append(f"| *R*²                | {results['Prompt']['R2']:>11} | {results['Followup']['R2']:>11} | {results['All']['R2']:>11} |")
lines.append(f"| Adj. *R*²           | {results['Prompt']['AdjR2']:>11} | {results['Followup']['AdjR2']:>11} | {results['All']['AdjR2']:>11} |")
lines.append("")
lines.append("*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*")
path = pathlib.Path("/workspace/repro.txt")
path.write_text("\n".join(lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
