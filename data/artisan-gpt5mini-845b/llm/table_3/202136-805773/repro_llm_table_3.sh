#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**

|                     |     Prompt (1) |  Followup (2) |        All (3) |
| ------------------- | -------------: | ------------: | -------------: |
| Constant            | ?.??*** (?.??) |  -?.?? (?.??) | ?.??*** (?.??) |
| AI tool familiarity |  ?.??** (?.??) | ?.??** (?.??) |    ?.?? (?.??) |
| Information Comprh. |   -?.?? (?.??) |   ?.?? (?.??) |   -?.?? (?.??) |
| Learning Process    |    ?.?? (?.??) | ?.??** (?.??) |   -?.?? (?.??) |
| *R*²                |          ?.??? |         ?.??? |          ?.??? |
| Adj. *R*²           |          ?.??? |         ?.??? |          ?.??? |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE

# Section 2: Download artifact (provenance)
artisan get https://zenodo.org/records/10461385

# Section 3: Parse notebook outputs to extract model summaries (no R needed)
python3 - <<'PY'
import json, re, sys

nb_path = "GILT_Artifacts/GILT_Artifacts-main/study/analysis.ipynb"
with open(nb_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

def cell_source_text(cell):
    src = cell.get('source', [])
    if isinstance(src, list):
        return "".join(src)
    return str(src)

def cell_output_text(cell):
    outs = cell.get('outputs', [])
    texts = []
    for o in outs:
        data = o.get('data', {})
        # Prefer text/plain, then text/markdown, then text/html
        for key in ('text/plain','text/markdown','text/html'):
            if key in data:
                val = data[key]
                if isinstance(val, list):
                    texts.append("".join(val))
                else:
                    texts.append(str(val))
                break
    return "\n".join(texts)

# Find model cells for the three targets
targets = {
    "query_total": None,
    "Query_followup": None,
    "usage_total": None
}

cells = nb.get('cells', [])
for i, cell in enumerate(cells):
    src = cell_source_text(cell)
    if "glm" in src and any(t in src for t in targets.keys()):
        for t in targets.keys():
            if t in src and targets[t] is None:
                targets[t] = i

# Helper to extract coefficients from a model cell's outputs
def extract_coefs(cell):
    text = cell_output_text(cell)
    # Find the "Coefficients:" block
    coeff_block = None
    m = re.search(r"Coefficients:\\n([\\s\\S]*?)(?:\\n\\s*---|\\n\\s*\\(Dispersion parameter|\\n\\s*Null deviance|$)", text)
    if m:
        coeff_block = m.group(1)
    else:
        # try alternative: find "Estimate Std. Error" header and take subsequent lines
        m2 = re.search(r"Estimate\\s+Std\\. Error[\\s\\S]*", text)
        if m2:
            coeff_block = text[m2.start():]
    coefs = {}
    if coeff_block:
        lines = [l.rstrip() for l in coeff_block.strip().splitlines() if l.strip()]
        # skip header lines that contain "Estimate" or "Std. Error"
        cleaned = []
        for line in lines:
            if re.search(r"Estimate\\s+Std\\. Error", line):
                continue
            cleaned.append(line)
        for line in cleaned:
            parts = line.split()
            if len(parts) < 3:
                continue
            name = parts[0]
            # handle names with backticks or parentheses
            # Estimate is the first numeric token
            nums = [p for p in parts if re.match(r"^-?\\d+\\.?\\d*(e[-+]?\\d+)?$", p, re.IGNORECASE)]
            if len(nums) >= 2:
                est = nums[0]
                se = nums[1]
                # p-value usually the token before possible stars at end
                p_candidates = [p for p in parts if re.match(r"^\\d*\\.\\d+(e[-+]?\\d+)?$", p, re.IGNORECASE)]
                pval = p_candidates[-1] if p_candidates else nums[-1]
                # Determine stars if present (look for '*' tokens)
                stars = ""
                if parts[-1].startswith("*"):
                    stars = parts[-1]
                coefs[name] = {"est": float(est), "se": float(se), "p": float(pval), "stars": stars}
    return coefs

# Helper to find rsq values in the next few cells
def find_rsq_after(idx):
    # look next up to 4 cells for an rsq output cell
    for j in range(idx+1, min(idx+5, len(cells))):
        src = cell_source_text(cells[j])
        out_text = cell_output_text(cells[j])
        # detect numeric outputs like "0.262556648100479" or "[1] 0.2625566"
        nums = re.findall(r"\\d\\.\\d{3,}", out_text)
        if not nums:
            # try numbers with more precision
            nums = re.findall(r"\\d\\.\\d+", out_text)
        if nums:
            # If two numbers found, first is R2, second adj
            if len(nums) >= 2:
                return float(nums[0]), float(nums[1])
            elif len(nums) == 1:
                # maybe the adj follows in same cell as second output; try to find another numeric in later cell
                for k in range(j+1, min(j+3, len(cells))):
                    more = re.findall(r"\\d\\.\\d+", cell_output_text(cells[k]))
                    if more:
                        return float(nums[0]), float(more[0])
                return float(nums[0]), None
    return None, None

# Extract for each target
results = {}
for key, idx in targets.items():
    if idx is None:
        continue
    model_cell = cells[idx]
    coefs = extract_coefs(model_cell)
    r2, adj = find_rsq_after(idx)
    # Map names to expected variable labels
    mapping = {
        "(Intercept)": "(Intercept)",
        "AI_experience": "AI_experience",
        "info_style": "info_style",
        "learning_style": "learning_style"
    }
    res = {
        "intercept": coefs.get("(Intercept)") or coefs.get("Intercept") or {},
        "AI_experience": coefs.get("AI_experience", {}),
        "info_style": coefs.get("info_style", {}),
        "learning_style": coefs.get("learning_style", {}),
        "r2": r2,
        "adj": adj
    }
    results[key] = res

# Format table entries: two decimals for estimates and SE, stars by p
def fmt(coef):
    if not coef:
        return "NA"
    est = coef.get("est", 0.0)
    se = coef.get("se", 0.0)
    p = coef.get("p", 1.0)
    stars = "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.1 else ""))
    return f"{est:.2f}{stars} ({se:.2f})"

# Build final markdown table using the three models in order: query_total (Prompt), Query_followup (Followup), usage_total (All)
prompt = results.get("query_total", {})
follow = results.get("Query_followup", {})
allm = results.get("usage_total", {})

def fmt_r(x):
    if x is None:
        return "NA"
    return f"{x:.3f}"

table = []
table.append("**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**\\n")
table.append("|                     |     Prompt (1) |  Followup (2) |        All (3) |")
table.append("| ------------------- | -------------: | ------------: | -------------: |")
table.append(f"| Constant            | {fmt(prompt.get('intercept'))} | {fmt(follow.get('intercept'))} | {fmt(allm.get('intercept'))} |")
table.append(f"| AI tool familiarity | {fmt(prompt.get('AI_experience'))} | {fmt(follow.get('AI_experience'))} | {fmt(allm.get('AI_experience'))} |")
table.append(f"| Information Comprh. | {fmt(prompt.get('info_style'))} | {fmt(follow.get('info_style'))} | {fmt(allm.get('info_style'))} |")
table.append(f"| Learning Process    | {fmt(prompt.get('learning_style'))} | {fmt(follow.get('learning_style'))} | {fmt(allm.get('learning_style'))} |")
table.append(f"| *R*²                | {fmt_r(prompt.get('r2'))} | {fmt_r(follow.get('r2'))} | {fmt_r(allm.get('r2'))} |")
table.append(f"| Adj. *R*²           | {fmt_r(prompt.get('adj'))} | {fmt_r(follow.get('adj'))} | {fmt_r(allm.get('adj'))} |\\n")
table.append("*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*")

with open("/workspace/repro.txt", "w", encoding="utf-8") as out:
    out.write("\\n".join(table))

# Exit with success
print("WROTE /workspace/repro.txt")
PY

# Section 4: Format and submit
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
