#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**

|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |
| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |
|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |
| **Avg.** |      ??      |        ??        |          ???         |  **???**  |   ?,???  |  ?,??? |
| **Mdn.** |       ?      |         ?        |          ???         |  **???**  |   ?,???  |  ?,??? |

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809

# Section 3: Reproduction commands (populate from reviewed steps)
# Convert the evaluation PDF with all per-issue metrics into Markdown
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/eval_results.md

# Parse the Markdown to compute averages and medians, then emit Table 4 to /workspace/repro.txt
python - << 'PY'
from statistics import mean, median

md_path = "/workspace/eval_results.md"
with open(md_path, "r") as f:
    lines = f.read().splitlines()

# Locate the metric header row
hdr_idx = None
for i, l in enumerate(lines):
    if l.startswith("||Issue id|Link|"):
        hdr_idx = i
        break
if hdr_idx is None:
    raise SystemExit("Metric header not found")

data_start = hdr_idx + 2  # skip alignment row

# Column indices based on the header:
#  -  8: ROAM Total Running Time
#  -  9: ROAM PRM Construction Time
#  - 10: ROAM Event Search Time
#  - 11: ROAM Path Recovery and Execution Time
#  - 23: ReCDroid Running Time
#  - 55: Yakusu Running Time
cols = {
    "roam_total": 8,
    "roam_prm": 9,
    "roam_event": 10,
    "roam_path": 11,
    "recdroid": 23,
    "yakusu": 55,
}

values = {k: [] for k in cols}

for l in lines[data_start:]:
    if not l.startswith("|"):
        break
    cells = [c.strip() for c in l.strip().split("|")[1:-1]]
    if len(cells) <= max(cols.values()):
        continue
    for name, idx in cols.items():
        v = cells[idx]
        try:
            num = float(v)
        except ValueError:
            continue
        values[name].append(num)

def fmt(x: float) -> str:
    # Format with thousands separators and two decimal places
    return f"{x:,.2f}"

stats = {}
for name in cols:
    arr = values[name]
    if not arr:
        raise SystemExit(f"No numeric data collected for {name}")
    stats[name] = {
        "avg": mean(arr),
        "mdn": median(arr),
        "n": len(arr),
    }

# Prepare Table 4 content
lines_out = []
lines_out.append("**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**")
lines_out.append("")
lines_out.append("|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |")
lines_out.append("| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |")
lines_out.append("|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |")
lines_out.append(
    "| **Avg.** | {prm} | {event} | {path} |  **{total}**  |   {recdroid}  |  {yakusu} |".format(
        prm=fmt(stats["roam_prm"]["avg"]),
        event=fmt(stats["roam_event"]["avg"]),
        path=fmt(stats["roam_path"]["avg"]),
        total=fmt(stats["roam_total"]["avg"]),
        recdroid=fmt(stats["recdroid"]["avg"]),
        yakusu=fmt(stats["yakusu"]["avg"]),
    )
)
lines_out.append(
    "| **Mdn.** | {prm} | {event} | {path} |  **{total}**  |   {recdroid}  |  {yakusu} |".format(
        prm=fmt(stats["roam_prm"]["mdn"]),
        event=fmt(stats["roam_event"]["mdn"]),
        path=fmt(stats["roam_path"]["mdn"]),
        total=fmt(stats["roam_total"]["mdn"]),
        recdroid=fmt(stats["recdroid"]["mdn"]),
        yakusu=fmt(stats["yakusu"]["mdn"]),
    )
)

with open("/workspace/repro.txt", "w") as f:
    f.write("\n".join(lines_out) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
