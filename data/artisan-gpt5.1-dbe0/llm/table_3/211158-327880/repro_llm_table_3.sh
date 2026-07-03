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

# Section 2: Artifact download
artisan get https://zenodo.org/records/10461385

# Section 3: Reproduction commands (data-driven GLM + R² computation)
python - <<'PY'
import csv, math
from pathlib import Path

DATA_PATH = Path("GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv")

def read_rows(path, outcome_col):
    rows = []
    with path.open() as f:
        r = csv.DictReader(f)
        for row in r:
            if row.get("tool") != "1":
                continue
            try:
                yv = float(row[outcome_col])
                x1 = float(row["AI_experience"])
                x2 = float(row["info_style"])
                x3 = float(row["learning_style"])
            except (ValueError, KeyError):
                continue
            rows.append((yv, [1.0, x1, x2, x3]))
    return rows

def mat_transpose(M):
    return [list(col) for col in zip(*M)]

def mat_vec_mul(A, v):
    m, n = len(A), len(A[0])
    assert len(v) == n
    out = [0.0]*m
    for i in range(m):
        s = 0.0
        Ai = A[i]
        for j in range(n):
            s += Ai[j]*v[j]
        out[i] = s
    return out

def solve_linear(A, b):
    n = len(A)
    M = [row[:] for row in A]
    x = list(b)
    for k in range(n):
        pivot = max(range(k, n), key=lambda i: abs(M[i][k]))
        if abs(M[pivot][k]) < 1e-12:
            raise RuntimeError("Singular matrix")
        if pivot != k:
            M[k], M[pivot] = M[pivot], M[k]
            x[k], x[pivot] = x[pivot], x[k]
        for i in range(k+1, n):
            factor = M[i][k] / M[k][k]
            if factor == 0.0:
                continue
            for j in range(k, n):
                M[i][j] -= factor * M[k][j]
            x[i] -= factor * x[k]
    for i in range(n-1, -1, -1):
        s = x[i]
        for j in range(i+1, n):
            s -= M[i][j]*x[j]
        x[i] = s / M[i][i]
    return x

def invert_matrix(A):
    n = len(A)
    M = [row[:] for row in A]
    inv = [[float(i==j) for j in range(n)] for i in range(n)]
    for k in range(n):
        pivot = max(range(k, n), key=lambda i: abs(M[i][k]))
        if abs(M[pivot][k]) < 1e-12:
            raise RuntimeError("Singular matrix in invert")
        if pivot != k:
            M[k], M[pivot] = M[pivot], M[k]
            inv[k], inv[pivot] = inv[pivot], inv[k]
        diag = M[k][k]
        for j in range(n):
            M[k][j] /= diag
            inv[k][j] /= diag
        for i in range(n):
            if i == k:
                continue
            factor = M[i][k]
            if factor == 0.0:
                continue
            for j in range(n):
                M[i][j] -= factor * M[k][j]
                inv[i][j] -= factor * inv[k][j]
    return inv

def glm_poisson_IRLS(rows, max_iter=50, tol=1e-10):
    """Fit Poisson-log GLM by IRLS, return y, mu, beta, se."""
    y = [r[0] for r in rows]
    X = [r[1] for r in rows]
    n = len(y)
    p = len(X[0])
    beta = [0.0]*p
    for _ in range(max_iter):
        eta = mat_vec_mul(X, beta)
        mu = [math.exp(e) for e in eta]
        W = mu[:]  # Poisson weights
        z = []
        for i in range(n):
            if mu[i] <= 0:
                z.append(eta[i])
            else:
                z.append(eta[i] + (y[i] - mu[i]) / mu[i])
        XT = mat_transpose(X)
        XT_WX = [[0.0]*p for _ in range(p)]
        XT_Wz = [0.0]*p
        for j in range(p):
            for k in range(p):
                s = 0.0
                for i in range(n):
                    s += XT[j][i] * W[i] * X[i][k]
                XT_WX[j][k] = s
            sz = 0.0
            for i in range(n):
                sz += XT[j][i] * W[i] * z[i]
            XT_Wz[j] = sz
        beta_new = solve_linear(XT_WX, XT_Wz)
        diff = max(abs(beta_new[j] - beta[j]) for j in range(p))
        beta = beta_new
        if diff < tol:
            break
    eta = mat_vec_mul(X, beta)
    mu = [math.exp(e) for e in eta]
    # Quasi-Poisson dispersion via Pearson residuals
    pearson = 0.0
    for i in range(n):
        if mu[i] > 0:
            pearson += (y[i] - mu[i])**2 / mu[i]
    phi = pearson / (n - p)
    XT = mat_transpose(X)
    XT_WX = [[0.0]*p for _ in range(p)]
    for j in range(p):
        for k in range(p):
            s = 0.0
            for i in range(n):
                s += XT[j][i] * mu[i] * X[i][k]
            XT_WX[j][k] = s
    XT_WX_inv = invert_matrix(XT_WX)
    se = [math.sqrt(phi * XT_WX_inv[j][j]) for j in range(p)]
    return y, mu, beta, se

def efron_r2(y, mu):
    n = len(y)
    ybar = sum(y)/n
    ss_res = sum((yi - mi)**2 for yi, mi in zip(y, mu))
    ss_tot = sum((yi - ybar)**2 for yi in y)
    if ss_tot == 0:
        return float("nan")
    return 1.0 - ss_res/ss_tot

def adj_r2_lm_style(r2, n, k_predictors):
    # k_predictors excludes intercept (here: 3 predictors)
    denom = n - k_predictors - 1
    if denom <= 0:
        return float("nan")
    return 1.0 - (1.0 - r2) * (n - 1) / denom

def stars_for(beta, se):
    out = []
    for b, s in zip(beta, se):
        if s <= 0:
            out.append('')
            continue
        z = b / s
        from math import erf, sqrt
        p = 2.0 * (1.0 - 0.5 * (1.0 + erf(abs(z) / math.sqrt(2.0))))
        if p < 0.01:
            out.append('***')
        elif p < 0.05:
            out.append('**')
        elif p < 0.1:
            out.append('*')
        else:
            out.append('')
    return out

def fit_and_summarize(outcome_col):
    rows = read_rows(DATA_PATH, outcome_col)
    y, mu, beta, se = glm_poisson_IRLS(rows)
    n = len(y)
    # 3 predictors (AI_experience, info_style, learning_style)
    r2 = efron_r2(y, mu)
    r2_adj = adj_r2_lm_style(r2, n, k_predictors=3)
    st = stars_for(beta, se)
    return beta, se, st, r2, r2_adj

beta_p, se_p, st_p, r2_p, r2a_p = fit_and_summarize("query_total")
beta_f, se_f, st_f, r2_f, r2a_f = fit_and_summarize("Query_followup")
beta_a, se_a, st_a, r2_a, r2a_a = fit_and_summarize("usage_total")

def fmt_coef(b, s, st):
    # two decimals, no leading '+'
    sgn = "-" if b < 0 else ""
    return f"{sgn}{abs(b):.2f}{st} ({s:.2f})"

def row_entries(beta, se, st):
    return [fmt_coef(beta[i], se[i], st[i]) for i in range(4)]

const_p, ai_p, info_p, learn_p = row_entries(beta_p, se_p, st_p)
const_f, ai_f, info_f, learn_f = row_entries(beta_f, se_f, st_f)
const_a, ai_a, info_a, learn_a = row_entries(beta_a, se_a, st_a)

def fmt_r2(v):
    return f"{v:.3f}" if isinstance(v, float) and not math.isnan(v) else "?.???"

lines = []
lines.append("**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**\n")
lines.append("")
lines.append("|                     |     Prompt (1) |  Followup (2) |        All (3) |")
lines.append("| ------------------- | -------------: | ------------: | -------------: |")
lines.append(f"| Constant            | {const_p} | {const_f} | {const_a} |")
lines.append(f"| AI tool familiarity | {ai_p} | {ai_f} | {ai_a} |")
lines.append(f"| Information Comprh. | {info_p} | {info_f} | {info_a} |")
lines.append(f"| Learning Process    | {learn_p} | {learn_f} | {learn_a} |")
lines.append(f"| *R*²                |        {fmt_r2(r2_p)} |        {fmt_r2(r2_f)} |        {fmt_r2(r2_a)} |")
lines.append(f"| Adj. *R*²           |        {fmt_r2(r2a_p)} |        {fmt_r2(r2a_f)} |        {fmt_r2(r2a_a)} |")
lines.append("")
lines.append("*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*")

with open("/workspace/repro.txt", "w") as f:
    f.write("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
