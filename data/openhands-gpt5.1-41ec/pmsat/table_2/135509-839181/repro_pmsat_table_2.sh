#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched \\delta_g and dominant \\delta transitions.**

| (n) | (n_{reach}) | # Glitches | Mean (\\delta_g) fr. | Max (\\delta_g) fr. | Min (\\delta) fr. |
| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |
|   3 |           3 |         31 |                7.75 |                 26 |               65 |
|   4 |           4 |          5 |                1.25 |                  2 |               26 |

EOTABLE

# Section 2: Artifact download
if [ ! -d /workspace/pmsat-artifacts/pmsat-inference ]; then
  cd /workspace
  curl -L -o pmsat-artifacts.zip "https://zenodo.org/api/records/10423670/files/pmsat-inference-and-publication-artifacts.zip/content"
  rm -rf /workspace/pmsat-artifacts
  unzip -q pmsat-artifacts.zip -d pmsat-artifacts
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/pmsat-artifacts/pmsat-inference

# Build Docker image for the PMSAT environment
docker-compose build

# Mine models from ping pong example traces (as in README Figure/Table 2)
docker-compose run pmsat python run_pmsat_on_traces.py examples-results/ping_pong_example/info.json -nmax 7

# Extract the Table 2 statistics directly from the JSON result files
python - <<'PY'
import json
import os
from pathlib import Path

# Directory with results for ping-pong example (fixed hash from README)
res_dir = Path("/workspace/pmsat-artifacts/pmsat-inference/TRACE-results/92e710ef352c4739cd7569794272588a")
if not res_dir.exists():
    raise SystemExit(f"Results directory {res_dir} does not exist")

# Collect all JSON result files
table_results = []
for root, _, files in os.walk(res_dir):
    for name in files:
        if not name.endswith(".json"):
            continue
        if not name.startswith("pmsatLearned-"):
            continue
        path = Path(root) / name
        with path.open("r") as f:
            table_results.append(json.load(f))

# Sort by number of states
table_results.sort(key=lambda x: x["num_states"])

# Column labels used in the JSON results
DOM_LABEL = "dominant_delta_freq"
GLITCH_LABEL = "glitched_delta_freq"
REACH_LABEL = "dominant_reachable_states"
COST_LABEL = "cost"
NSTATES_LABEL = "num_states"

rows = []
for res in table_results:
    n = res[NSTATES_LABEL]
    if n not in (3, 4):
        continue
    dom_freq = res[DOM_LABEL]
    glitch_freq = res[GLITCH_LABEL] or [0]
    n_reach = res[REACH_LABEL]
    glitches = res[COST_LABEL]

    mean_dg = sum(glitch_freq) / len(glitch_freq)
    max_dg = max(glitch_freq)
    min_dom = min(dom_freq)

    rows.append((n, n_reach, glitches, mean_dg, max_dg, min_dom))

# Sort selected rows by n
rows.sort(key=lambda t: t[0])

lines = []
lines.append("**Table 2: Statistics of inferring ping-pong server with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched \\delta_g and dominant \\delta transitions.**")
lines.append("")
lines.append("| (n) | (n_{reach}) | # Glitches | Mean (\\delta_g) fr. | Max (\\delta_g) fr. | Min (\\delta) fr. |")
lines.append("| --: | ----------: | ---------: | ------------------: | -----------------: | ---------------: |")
for n, n_reach, glitches, mean_dg, max_dg, min_dom in rows:
    lines.append(
        f"| {n:3d} | {n_reach:11d} | {glitches:9d} | {mean_dg:18.2f} | {int(max_dg):17d} | {int(min_dom):15d} |"
    )

output = "\n".join(lines) + "\n"
Path("/workspace/repro.txt").write_text(output)
print(output, end="")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
