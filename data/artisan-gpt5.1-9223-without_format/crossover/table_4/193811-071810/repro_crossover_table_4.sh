#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Defect Detection Rates. For each fuzzer, we report the defect detection rate of each discovered defect across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest detection rate or rates (in the case of a tie) for each time and defect is highlighted in blue. Detection rates that differ significantly from Zeugma-Link’s are colored red.**

| Fuzzer       | B0 [2] 5M | B0 [2] 3H | B1 [3] 5M | B1 [3] 3H | C0 [11] 5M | C0 [11] 3H | C1 [12] 5M | C1 [12] 3H | N0 [42] 5M | N0 [42] 3H | N1 [40] 5M | N1 [40] 3H | N2 [41] 5M | N2 [41] 3H | R0 [31] 5M | R0 [31] 3H | R1 [30] 5M | R1 [30] 3H | R2 [28] 5M | R2 [28] 3H | R3 [29] 5M | R3 [29] 3H | R4 [32] 5M | R4 [32] 3H |
| ------------ | --------: | --------: | --------: | --------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |
| BeDiv-Simple |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| BeDiv-Struct |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| RLCheck      |         - |         - |         - |         - |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zest         |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-X     |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-1PT   |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-2PT   |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |
| Zeugma-Link  |      ?.?? |      ?.?? |      ?.?? |      ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |       ?.?? |      ?.??  |       ?.?? |       ?.?? |       ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Section 3: Reproduction commands (populate from reviewed steps)
# Use detections.csv to compute detection rates at 5 minutes and 3 hours,
# writing a Markdown table to /workspace/repro.txt.
python3 - <<'PY'
import csv
import os

workspace = '/workspace'
detections_path = os.path.join(workspace, 'detections.csv')
expected_path = os.path.join(workspace, 'expected.md')
repro_path = os.path.join(workspace, 'repro.txt')

# Read header/intro lines from expected.md so we can reuse the same caption and table header.
with open(expected_path, 'r', encoding='utf-8') as f:
    expected_lines = f.readlines()

# We assume the first four lines are:
# 0: caption line
# 1: blank line
# 2: header row
# 3: alignment row
header_line = None
for line in expected_lines:
    if line.lstrip().startswith('| Fuzzer'):
        header_line = line
        break
if header_line is None:
    raise RuntimeError('Could not find table header line in expected.md')

# Parse column labels from the header line.
header_cells = [c.strip() for c in header_line.strip().split('|')[1:-1]]
# header_cells[0] == 'Fuzzer', the rest are "<DEFECT> [ref] <TIME>"
data_columns = header_cells[1:]

# Map each measurement column to (defect_code, time_tag) in the order they appear.
col_specs = []
for cell in data_columns:
    parts = cell.split()
    if len(parts) < 2:
        raise RuntimeError(f'Unexpected header cell format: {cell!r}')
    defect_code = parts[0]          # e.g., 'B0'
    time_tag = parts[-1]            # e.g., '5M' or '3H'
    col_specs.append((defect_code, time_tag, cell))

# Time thresholds in seconds.
time_thresholds = {
    '5M': 5 * 60,
    '3H': 3 * 60 * 60,
}

# Fuzzer order as in the paper/code (tables.py: FUZZER_ORDER).
fuzzer_order = [
    'BeDiv-Simple',
    'BeDiv-Struct',
    'RLCheck',
    'Zest',
    'Zeugma-X',
    'Zeugma-1PT',
    'Zeugma-2PT',
    'Zeugma-Link',
]

def parse_time_to_seconds(s: str):
    """Parse time strings like '0 days 01:00:34.474000' to seconds (float).
    Return None for missing/NaT."""
    if not s:
        return None
    s = s.strip()
    if s == 'NaT':
        return None
    # Expected format: "<days> days HH:MM:SS[.fraction]"
    try:
        days_part, rest = s.split(' days ', 1)
        days = int(days_part)
    except ValueError:
        # Unexpected format; treat as missing.
        return None
    frac_sec = 0.0
    if '.' in rest:
        time_part, frac = rest.split('.', 1)
        # Keep only digits in fractional part.
        frac = ''.join(ch for ch in frac if ch.isdigit())
        if frac:
            # Convert fractional seconds; scale to [0,1).
            frac_sec = float('0.' + frac)
    else:
        time_part = rest
    try:
        h_str, m_str, s_str = time_part.split(':')
        h = int(h_str)
        m = int(m_str)
        s_int = int(s_str)
    except ValueError:
        return None
    total = days * 86400 + h * 3600 + m * 60 + s_int
    return total + frac_sec

# Load detections.csv and group detection times by (fuzzer, defect).
detections = {}
with open(detections_path, 'r', encoding='utf-8', newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        fuzzer = (row.get('fuzzer') or '').strip()
        defect = (row.get('defect') or '').strip()
        if not fuzzer or not defect:
            continue
        t_sec = parse_time_to_seconds((row.get('time') or '').strip())
        detections.setdefault((fuzzer, defect), []).append(t_sec)

def detection_rate(fuzzer: str, defect: str, time_tag: str):
    """Compute detection rate for (fuzzer, defect) by given time threshold."""
    times = detections.get((fuzzer, defect), [])
    if not times:
        # No campaigns for this (fuzzer, defect) combination: use '-' as in the paper for RLCheck on B0/B1.
        return None
    threshold = time_thresholds[time_tag]
    total = len(times)
    detected = sum(1 for t in times if t is not None and t < threshold)
    return detected / total

# Write reproduced table.
with open(repro_path, 'w', encoding='utf-8') as out:
    # Reuse caption + blank line + header + alignment row from expected.md.
    # This preserves the same table structure and alignment markers.
    for line in expected_lines[:4]:
        out.write(line.rstrip('\n') + '\n')
    # Now write one row per fuzzer in the prescribed order.
    for fuzzer in fuzzer_order:
        row_cells = [fuzzer]
        for defect_code, time_tag, _ in col_specs:
            rate = detection_rate(fuzzer, defect_code, time_tag)
            if rate is None:
                cell = '-'  # No data for this combo.
            else:
                cell = f'{rate:.2f}'
            row_cells.append(cell)
        out.write('| ' + ' | '.join(row_cells) + ' |\n')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
