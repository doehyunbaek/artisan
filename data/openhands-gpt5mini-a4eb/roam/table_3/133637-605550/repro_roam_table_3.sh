#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      29     |             27            |            30            |
| Yakusu   |      8      |             15            |             4            |
| Roam     |      94     |             96            |            93            |

EOTABLE

# Section 2: Artifact download
if [ ! -f /workspace/ROAM-Artifact.zip ]; then
  echo "Downloading ROAM-Artifact.zip (this may be large)..."
  curl -L 'https://zenodo.org/records/11068809/files/ROAM-Artifact.zip?download=1' -o /workspace/ROAM-Artifact.zip
else
  echo "ROAM-Artifact.zip already exists, skipping download."
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# Extract the results.pdf
unzip -j /workspace/ROAM-Artifact.zip 'ROAM-Artifact/Evaluation/results.pdf' -d /workspace

# Convert results.pdf to markdown (uses uvx helper)
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' /workspace/results.pdf > /workspace/results.md

# Parse the markdown and compute reproduction rates for ReCDroid, Yakusu, and ROAM
python3 - <<'PY' > /workspace/repro.txt
from pathlib import Path
s=Path('/workspace/results.md').read_text()
lines=[l for l in s.splitlines() if l.strip()!='']
start=None
for i,l in enumerate(lines):
    if l.startswith('|') and 'Issue id' in ''.join(lines[i:i+3]):
        start=i
        break
if start is None:
    raise SystemExit('Could not locate results table')
header_top = [c.strip() for c in lines[start].split('|')]
header_third = [c.strip() for c in lines[start+2].split('|')]
# find reproduction result column indices
repro_indices = [i for i,h in enumerate(header_third) if 'Reproduction' in h]
mapping = {}
for i in repro_indices:
    j=i
    while j>=0 and (header_top[j]=='' or header_top[j].startswith('Col')):
        j-=1
    approach = header_top[j] if j>=0 else 'UNKNOWN'
    mapping.setdefault(approach,[]).append(i)
# read data rows
data=[]
for l in lines[start+3:]:
    if not l.startswith('|'):
        break
    parts=[p.strip() for p in l.split('|')]
    data.append(parts)
# find missing steps column index
miss_idx = next((i for i,h in enumerate(header_third) if 'Missing' in h), None)
# approaches to report
targets = ['ReCDroid','Yakusu','ROAM']
results = {}
for t in targets:
    results[t]=[]
for row in data:
    if len(row) < len(header_third):
        row += ['']*(len(header_third)-len(row))
    miss = int(row[miss_idx]) if (miss_idx is not None and row[miss_idx].isdigit()) else 0
    for t in targets:
        idxs = mapping.get(t, [])
        if not idxs:
            continue
        col = idxs[0]
        val = row[col].lower()
        is_success = 'success' in val
        results[t].append((is_success, miss))
# helper
def pct(x,n):
    return round(100 * x / n) if n>0 else 0
# compute and output table
out = []
out.append('**Reproduced Table 3: Computed Reproduction Rates**')
out.append('')
out.append('|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |')
out.append('| -------- | :---------: | :-----------------------: | :----------------------: |')
for t in targets:
    vals = results.get(t, [])
    total = len(vals)
    all_success = sum(1 for s,m in vals if s)
    no_missing = [s for s,m in vals if m==0]
    with_missing = [s for s,m in vals if m>0]
    a = pct(all_success, total)
    b = pct(sum(no_missing), len(no_missing))
    c = pct(sum(with_missing), len(with_missing))
    out.append(f'| {t} |      {a}     |             {b}            |            {c}            |')
Path('/workspace/repro.txt').write_text('\n'.join(out))
print('\n'.join(out))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
