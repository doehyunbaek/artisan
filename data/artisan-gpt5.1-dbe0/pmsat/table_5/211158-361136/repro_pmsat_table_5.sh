#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       ? |         ?? |         ??.? |          ?? |         ? |
| 10 |       ? |         ?? |         ??.? |          ?? |         ? |
| 11 |      ?? |          ? |            ? |           ? |         ? |
| 13 |      ?? |          ? |            ? |           ? |         ? |
| 14 |      ?? |          ? |            ? |           ? |         ? |

EOTABLE

# Section 2: Artifact download
cd /workspace
artisan get https://zenodo.org/records/10423670

# Enter artifact root for PMSAT
cd /workspace/pmsat-inference-and-publication-artifacts/pmsat-inference

# Ensure Docker image is built (idempotent)
docker-compose build

# Section 3: Reproduction commands (populate from reviewed steps)

# 3.1 Mine models from the SmokeMeter trace up to nmax = 14
docker-compose run pmsat python run_pmsat_on_traces.py use_cases/avl415SE_smokemeter/smokemeter_trace.json -nmax 14

# 3.2 Compute Table 5 statistics directly from JSON results using plain Python
python - <<'PY' > /workspace/repro.txt
import json
from pathlib import Path

# Directory with results for the SmokeMeter trace (created by run_pmsat_on_traces.py)
base = Path("TRACE-results/2804424892661995c1e6a665fa35e490")

# Collect all pmsatLearned-*.json files (skip info.json)
files = [p for p in base.rglob("*.json") if p.name.startswith("pmsatLearned-")]

if not files:
    raise SystemExit("No pmsatLearned-*.json files found under " + str(base))

results = []
for p in files:
    with p.open("r") as f:
        results.append(json.load(f))

# Sort by number of states
results.sort(key=lambda x: x["num_states"])

rows = {}
for res in results:
    n = res["num_states"]
    dom = res["dominant_delta_freq"]
    gl = res["glitched_delta_freq"] or [0]
    n_reach = res["dominant_reachable_states"]
    glitches = res["cost"]

    def mean(seq):
        return float(sum(seq)) / len(seq) if seq else 0.0

    mean_gl = mean(gl)
    max_gl = max(gl) if gl else 0.0
    min_dom = min(dom) if dom else 0.0

    rows[n] = {
        "n_reach": int(n_reach),
        "glitches": int(glitches),
        "mean_gl": float(mean_gl),
        "max_gl": float(max_gl),
        "min_dom": float(min_dom),
    }

# Only the n values reported in the paper's Table 5
n_order = [9, 10, 11, 13, 14]

print("**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**")
print()
print("|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |")
print("| -: | ------: | ---------: | -----------: | ----------: | --------: |")

def fmt_float(x: float) -> str:
    # Match artifact-style: three significant digits, no unnecessary trailing zeros/decimal
    s = f"{x:.3}"
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return s

for n in n_order:
    r = rows[n]
    print(
        f"| {n:2d} | {r['n_reach']:7d} | {r['glitches']:9d} |"
        f" {fmt_float(r['mean_gl']):11} | {fmt_float(r['max_gl']):10} | {fmt_float(r['min_dom']):8} |"
    )
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
