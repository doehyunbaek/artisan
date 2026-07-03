#!/usr/bin/bash
set -e

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**

| PR status | # of PRs | # of BD removed |
| --------- | -------: | --------------: |
| Merged    |       30 |              35 |
| Approved  |        1 |               1 |
| Rejected  |        1 |               1 |
| Pending   |        4 |               5 |
| **Total** |   **36** |          **42** |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11095274

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/bloat-study-artifact-v1.0/gdrosos-bloat-study-artifact-0fe2fe5

# Create a fresh virtual environment and install dependencies
python -m venv .env
. .env/bin/activate
pip install -r requirements.txt

# Run the authors' RQ4 script to produce the ASCII table for Table 3
python scripts/rq4.py data/results/qualitative_results.json --table3 > /workspace/rq4_table3_raw.txt

# Parse the ASCII table output and render it as a Markdown table in /workspace/repro.txt
python - <<'PY'
import pathlib

raw_path = pathlib.Path("/workspace/rq4_table3_raw.txt")
lines = raw_path.read_text().splitlines()

rows = []
for line in lines:
    line = line.rstrip()
    if not line.startswith("| "):
        continue
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    # Keep header and the status rows
    if parts[0] in {"PR Status", "Merged", "Approved", "Pending", "Rejected", "Total"}:
        rows.append(parts)

# Build a lookup from status -> (num_prs, num_bd)
lookup = {r[0]: r[1:] for r in rows if r[0] != "PR Status"}

order = ["Merged", "Approved", "Rejected", "Pending", "Total"]

out_lines = []
out_lines.append("**Table 3: The status of our pull requests, proposing the removal of bloated dependencies (BD)**")
out_lines.append("")
out_lines.append("| PR status | # of PRs | # of BD removed |")
out_lines.append("| --------- | -------: | --------------: |")

for status in order:
    n_prs, n_bd = lookup[status]
    if status == "Total":
        status_cell = "**Total**"
        n_prs = f"**{n_prs}**"
        n_bd = f"**{n_bd}**"
    else:
        status_cell = status
    out_lines.append(f"| {status_cell:<9} | {n_prs:>7} | {n_bd:>14} |")

repro_path = pathlib.Path("/workspace/repro.txt")
repro_path.write_text("\n".join(out_lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
