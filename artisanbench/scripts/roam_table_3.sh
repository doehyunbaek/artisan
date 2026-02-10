#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ROAM-Artifact.zip https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content
unzip ROAM-Artifact.zip -d ROAM-Artifact
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf > /workspace/results.md

python3 - <<'PY'
import re, sys

md_path = '/workspace/results.md'
out_path = '/workspace/repro.txt'

try:
    with open(md_path, 'r', encoding='utf-8') as f:
        lines = [l.strip() for l in f if l.strip()]
except FileNotFoundError:
    sys.exit('results.md not found')

if not lines:
    sys.exit('results.md is empty')

# 1. Dynamically identify table headers and data start
header1 = []
header2 = []
data_lines = []
sep_idx = -1

# Find the separator line (e.g., |---|---|)
for i, line in enumerate(lines[:10]):  # Scan first 10 lines
    if set(line) <= set('|-: '):
        sep_idx = i
        break

if sep_idx != -1:
    # Line before separator is definitely a header
    header1 = [c.strip() for c in lines[sep_idx-1].split('|')[1:-1]]
    
    # Check if line AFTER separator is a secondary header (contains text like 'Reproduction' or 'Result')
    # or if it's data.
    if sep_idx + 1 < len(lines):
        candidate = lines[sep_idx+1]
        # Heuristic: if it contains 'reproduction' or 'success' or 'missing', treat as header
        if any(x in candidate.lower() for x in ['reproduction', 'result', 'missing', 'success']):
            header2 = [c.strip() for c in candidate.split('|')[1:-1]]
            data_lines = lines[sep_idx+2:]
        else:
            data_lines = lines[sep_idx+1:]
else:
    # No separator found? Try to assume line 0 is header
    if lines:
        header1 = [c.strip() for c in lines[0].split('|')[1:-1]]
        data_lines = lines[1:]

# Normalize header2 length
if len(header2) < len(header1):
    header2 += [''] * (len(header1) - len(header2))

# 2. Find Missing Steps Column Index
missing_idx = None
# Check header 2 first (more specific)
for i, h in enumerate(header2):
    if 'missing' in h.lower():
        missing_idx = i
        break
# Check header 1
if missing_idx is None:
    for i, h in enumerate(header1):
        if 'missing' in h.lower():
            missing_idx = i
            break
# Fallback: Check for "Steps" if "Missing" not found
if missing_idx is None:
    for headers in [header2, header1]:
        for i, h in enumerate(headers):
            if 'steps' in h.lower():
                missing_idx = i
                break
        if missing_idx is not None: break

if missing_idx is None:
    # Dump headers for debug purposes
    sys.stderr.write(f"Header 1: {header1}\nHeader 2: {header2}\n")
    sys.exit('Missing steps column not found')

# 3. Find Tool Columns
# Helper to check if a column header implies reproduction results
def is_result_col(h):
    h = h.lower()
    return 'reproduction' in h or 'result' in h or 'success' in h

tool_indices = {}
for tool in ['roam', 'recdroid', 'yakusu']:
    found = None
    # Strategy: Find tool name in H1, then look for result col in H2 at similar index
    for i, h in enumerate(header1):
        if tool in h.lower():
            # Tool found in main header. Look for "Reproduction/Result" column nearby
            # Check the exact index first
            if i < len(header2) and is_result_col(header2[i]):
                found = i
                break
            # Check next few columns (header spanning)
            for offset in range(1, 4):
                if i + offset < len(header2) and is_result_col(header2[i+offset]):
                    found = i + offset
                    break
            # If no subheader found, assume the main header column is the one
            if found is None:
                found = i
            break
    
    # If not found in H1, check if H1+H2 combined string matches (weird formatting)
    if found is None:
        for i, (h1, h2) in enumerate(zip(header1, header2)):
            if tool in (h1 + ' ' + h2).lower() and is_result_col(h2):
                found = i
                break

    tool_indices[tool.lower()] = [found] if found is not None else []

# 4. Process Rows
rows = []
for l in data_lines:
    if not l.strip(): continue
    if set(l.strip()) <= set('|- '): continue # Skip extra separators
    cells = [c.strip() for c in l.split('|')[1:-1]]
    if len(cells) < len(header1):
        cells += [''] * (len(header1) - len(cells))
    rows.append(cells)

total_all = len(rows)
total_no_missing = 0
for r in rows:
    val_str = r[missing_idx].strip()
    # Extract number from string (e.g. "0 steps")
    nums = re.findall(r'\d+', val_str)
    if nums and int(nums[0]) == 0:
        total_no_missing += 1

total_with_missing = total_all - total_no_missing

def count_success(cols):
    ca = cn = cw = 0
    for r in rows:
        ok = False
        for col in cols:
            if col is None or col < 0 or col >= len(r): continue
            cell = r[col].lower()
            if 'success' in cell:
                ok = True
                break
        
        if ok:
            ca += 1
            # Check missing steps status for this row
            val_str = r[missing_idx].strip()
            nums = re.findall(r'\d+', val_str)
            if nums and int(nums[0]) == 0:
                cn += 1
            else:
                cw += 1
    return ca, cn, cw

results = {}
for t in ['recdroid', 'yakusu', 'roam']:
    cols = tool_indices.get(t, [])
    if not cols:
        results[t] = (0, 0, 0)
    else:
        results[t] = count_success(cols)

def pct(n, d):
    return round((n / d * 100) if d > 0 else 0.0, 2)

lines_out = []
lines_out.append('tool,all_reports_percent,reports_no_missing_percent,reports_with_missing_percent,all_counts,total_no_missing,total_with_missing')
for t, (ca, cn, cw) in results.items():
    lines_out.append(f'{t},{pct(ca, total_all)},{pct(cn, total_no_missing)},{pct(cw, total_with_missing)},{ca},{cn},{cw}')

with open(out_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines_out) + '\n')
print('\n'.join(lines_out))
PY

echo '<artisan_submit>'
python3 - <<'PY'
import csv

rows = {r["tool"].lower(): r for r in csv.DictReader(open("/workspace/repro.txt", encoding="utf-8", errors="replace"))}
order = [("ReCDroid","recdroid"),("Yakusu","yakusu"),("Roam","roam")]
fmt = lambda x: f"{round(float(x)):.0f}"

print("**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**\n")
print("|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |")
print("| -------- | :---------: | :-----------------------: | :----------------------: |")
for disp, key in order:
    r = rows[key]
    print(f"| {disp:<8} | {fmt(r['all_reports_percent']):^11} | {fmt(r['reports_no_missing_percent']):^25} | {fmt(r['reports_with_missing_percent']):^24} |")
PY
echo '</artisan_submit>'
