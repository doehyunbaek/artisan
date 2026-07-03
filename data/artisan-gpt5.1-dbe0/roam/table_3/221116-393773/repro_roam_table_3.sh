#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      ??     |             ??            |            ??            |
| Yakusu   |      ?      |             ??            |             ?            |
| Roam     |      ??     |             ??            |            ??            |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809

# Section 3: Reproduction commands (derive results from detailed per-subject data in the artifact)
cd /workspace/ROAM-Artifact/ROAM-Artifact

# Locate the evaluation PDF (which contains per-subject outcomes for each approach)
pdf_path=$(ls Evaluation/*.pdf | head -n 1)

# Convert it to Markdown for easier parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' "$pdf_path" > /workspace/results.md

# Parse the Markdown to compute reproduction rates for ReCDroid, Yakusu, and Roam
python - << 'PY'
from pathlib import Path

lines = Path("/workspace/results.md").read_text().splitlines()

# Data rows: lines that start with '|' and whose second cell is a numeric row index
data_rows = [l for l in lines if l.startswith("|") and l.split("|")[1].strip().isdigit()]

# Column indices based on inspection of the header:
# index: 0 '', 1 row#, 2 issue id, 3 link, 4 #actual, 5 #provided, 6 #missing, ...
IDX_MISSING = 6          # "# Missing Steps"
IDX_ROAM_REPRO = 8       # ROAM reproduction result
IDX_RECDROID_REPRO = 23  # ReCDroid reproduction result
IDX_YAKUSU_REPRO = 55    # Yakusu reproduction result

def categorize(missing_str):
    """Classify a subject as having missing steps or not."""
    try:
        m = int(missing_str)
    except ValueError:
        m = int(float(missing_str))
    return "no-missing" if m == 0 else "missing"

tools = {
    "Roam": IDX_ROAM_REPRO,
    "ReCDroid": IDX_RECDROID_REPRO,
    "Yakusu": IDX_YAKUSU_REPRO,
}

# Counters: tool -> category -> [success_count, total_count]
stats = {t: {"all": [0, 0], "no-missing": [0, 0], "missing": [0, 0]} for t in tools}

for line in data_rows:
    parts = [p.strip() for p in line.split("|")]
    cat = categorize(parts[IDX_MISSING])
    for tool, idx in tools.items():
        res = parts[idx]
        if not res:
            continue  # tool not evaluated on this subject
        stats[tool]["all"][1] += 1
        stats[tool][cat][1] += 1
        if res == "success":
            stats[tool]["all"][0] += 1
            stats[tool][cat][0] += 1

def pct(success, total):
    if total == 0:
        return 0.0
    return 100.0 * success / total

out_lines = []
out_lines.append("**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**\n")
out_lines.append("|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |")
out_lines.append("| -------- | :---------: | :-----------------------: | :----------------------: |")

for tool in ["ReCDroid", "Yakusu", "Roam"]:
    s_all, t_all = stats[tool]["all"]
    s_no, t_no = stats[tool]["no-missing"]
    s_m, t_m = stats[tool]["missing"]
    pa = pct(s_all, t_all)
    pn = pct(s_no, t_no)
    pm = pct(s_m, t_m)
    # Round to nearest integer percentage as typically reported in the paper
    row = f"| {tool:7s} | {pa:9.0f} | {pn:23.0f} | {pm:22.0f} |"
    out_lines.append(row)

Path("/workspace/repro.txt").write_text("\n".join(out_lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
