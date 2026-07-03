#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md << 'EOTABLE'
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
# Convert the results PDF to markdown and compute statistics
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf | python3 << 'PYTHON_EOF'
import sys
import statistics

def parse_float(s):
    s = s.strip()
    if not s or s == 'N/A' or s == 'N/A ':
        return None
    try:
        return float(s)
    except ValueError:
        return None

# Read all lines from stdin
lines = [line.rstrip('\n') for line in sys.stdin]
if not lines:
    sys.exit(1)

# Find the start of the table
start_idx = 0
for i, line in enumerate(lines):
    if line.startswith('|Col1|'):
        start_idx = i
        break

# The two header lines
header1 = lines[start_idx].strip('|').split('|')
header2 = lines[start_idx+1].strip('|').split('|')

# Find column indices
total_idx = None
prm_idx = None
event_idx = None
path_idx = None
recdroid_idx = None
yakusu_idx = None

for i, (h1, h2) in enumerate(zip(header1, header2)):
    h1 = h1.strip()
    h2 = h2.strip()
    if h1 == 'ROAM' and h2 == 'Running Time':
        total_idx = i
    elif 'PRM' in h2 and 'Construction' in h2:
        prm_idx = i
    elif 'Event' in h2 and 'Search' in h2:
        event_idx = i
    elif 'Path' in h2 and 'Recovery' in h2:
        path_idx = i
    elif h1 == 'ReCDroid' and h2 == 'Running Time':
        recdroid_idx = i
    elif h1 == 'Yakusu' and h2 == 'Running Time':
        yakusu_idx = i

# Fallback to known indices
if total_idx is None:
    total_idx = 8
if prm_idx is None:
    prm_idx = 9
if event_idx is None:
    event_idx = 10
if path_idx is None:
    path_idx = 11
if recdroid_idx is None:
    recdroid_idx = 23
if yakusu_idx is None:
    yakusu_idx = 55

# Find the first data row
data_start = 0
for i in range(start_idx, len(lines)):
    if lines[i].startswith('|1|'):
        data_start = i
        break

# Collect data
total_times = []
prm_times = []
event_times = []
path_times = []
recdroid_times = []
yakusu_times = []

for line in lines[data_start:]:
    if not line.startswith('|'):
        continue
    cells = line.strip('|').split('|')
    if len(cells) <= max(total_idx, prm_idx, event_idx, path_idx, recdroid_idx, yakusu_idx):
        continue
    total_val = parse_float(cells[total_idx])
    prm_val = parse_float(cells[prm_idx])
    event_val = parse_float(cells[event_idx])
    path_val = parse_float(cells[path_idx])
    recdroid_val = parse_float(cells[recdroid_idx])
    yakusu_val = parse_float(cells[yakusu_idx])
    if total_val is not None:
        total_times.append(total_val)
    if prm_val is not None:
        prm_times.append(prm_val)
    if event_val is not None:
        event_times.append(event_val)
    if path_val is not None:
        path_times.append(path_val)
    if recdroid_val is not None:
        recdroid_times.append(recdroid_val)
    if yakusu_val is not None:
        yakusu_times.append(yakusu_val)

# Compute statistics
def avg_med(data):
    if not data:
        return 0.0, 0.0
    avg = sum(data) / len(data)
    med = statistics.median(data)
    return avg, med

prm_avg, prm_med = avg_med(prm_times)
event_avg, event_med = avg_med(event_times)
path_avg, path_med = avg_med(path_times)
total_avg, total_med = avg_med(total_times)
recdroid_avg, recdroid_med = avg_med(recdroid_times)
yakusu_avg, yakusu_med = avg_med(yakusu_times)

# Write to repro.txt
with open('/workspace/repro.txt', 'w') as f:
    f.write("**Table 4: The Running Time Results of Each Approach (Shown in Seconds)**\n\n")
    f.write("|          | - **ROAM** - |                  |                      |           | ReCDroid | Yakusu |\n")
    f.write("| :------: | :----------: | :--------------: | :------------------: | :-------: | :------: | :----: |\n")
    f.write("|          |    **PRM**   | **Event Search** | **Path Recv & Exec** | **Total** |          |        |\n")
    f.write(f"| **Avg.** |      {prm_avg:.1f}      |        {event_avg:.1f}        |          {path_avg:.1f}         |  **{total_avg:.1f}**  |   {recdroid_avg:,.0f}  |  {yakusu_avg:,.0f} |\n")
    f.write(f"| **Mdn.** |      {prm_med:.1f}      |        {event_med:.1f}        |          {path_med:.1f}         |  **{total_med:.1f}**  |   {recdroid_med:,.0f}  |  {yakusu_med:,.0f} |\n")

PYTHON_EOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
