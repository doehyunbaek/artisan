#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: The Match Accuracy and Reproduction Rate for RQ5**

|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |
| --------- | :---------------------: | :-------------------: |
| Roam-Sim  |            ??           |           ??          |
| Roam-Dist |            ??           |           ??          |
| Roam      |            ??           |           ??          |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
# Convert Evaluation results PDF to markdown for parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results_md.md
# Compute average match accuracy and reproduction rate for Roam variants and emit Table 5
uvx --from python python - << 'PY' > /workspace/repro.txt
import pathlib

path = pathlib.Path("/workspace/results_md.md")
lines = path.read_text(encoding="utf-8").splitlines()

def parse_line(line):
    if not line.startswith("|"):
        return None
    if line.startswith("|Col1") or line.startswith("|---") or line.startswith("||"):
        return None
    parts = line.strip().split("|")
    # Require enough columns to cover all techniques
    if len(parts) < 19:
        return None
    return parts

rows = [p for p in map(parse_line, lines) if p]

def stats(ma_idx, rr_idx):
    ma_sum = 0.0
    success = 0
    cnt = 0
    for cols in rows:
        try:
            ma = float(cols[ma_idx])
        except (ValueError, IndexError):
            continue
        ma_sum += ma
        cnt += 1
        try:
            if cols[rr_idx].strip() == "success":
                success += 1
        except IndexError:
            pass
    avg_ma = ma_sum / cnt * 100.0
    repro_rate = success / cnt * 100.0
    return avg_ma, repro_rate

# Column indices (0-based over split parts, including leading/trailing empties):
# ROAM:      match accuracy -> 7,  reproduction result -> 8
# Roam-Sim:  match accuracy -> 13, reproduction result -> 14
# Roam-Dist: match accuracy -> 16, reproduction result -> 17
avg_roam, rr_roam = stats(7, 8)
avg_sim, rr_sim   = stats(13, 14)
avg_dist, rr_dist = stats(16, 17)

print("**Table 5: The Match Accuracy and Reproduction Rate for RQ5**")
print()
print("|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |")
print("| --------- | :---------------------: | :-------------------: |")
print(f"| Roam-Sim  |          {avg_sim:.2f}         |         {rr_sim:.2f}        |")
print(f"| Roam-Dist |          {avg_dist:.2f}         |         {rr_dist:.2f}        |")
print(f"| Roam      |          {avg_roam:.2f}         |         {rr_roam:.2f}        |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
