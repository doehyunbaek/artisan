#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Demographics of our dataset of 107 Java projects**

|                           |    Q1 |  Q2 |   Q3 | min |     max |
| ------------------------- | ----: | --: | ---: | --: | ------: |
| (p)’s direct dependencies |   4.5 |   7 |    9 |   2 |      22 |
| releases ((N_R))          |   138 | 336 | 2771 |  16 |  39,474 |
| libraries ((N_L))         |  12.5 |  40 |  134 |   4 |     960 |
| dependency edges ((E_D))  | 114.5 | 394 | 7066 |   9 | 141,429 |
| versions edges ((E_V))    |   137 | 335 | 2770 |  15 |  39,473 |

EOTABLE

# Section 2: Artifact download (if not already present)
ZIP_PATH=/workspace/ASE24_data_and_tools.zip
if [ ! -f "$ZIP_PATH" ]; then
  echo "Downloading artifact..."
  curl -L -o "$ZIP_PATH" 'https://zenodo.org/records/13741330/files/ASE24_data_and_tools.zip?download=1'
fi

# Section 3: Reproduction commands
# We'll try to read the CSV inside the archive and compute the required statistics.
python3 - <<'PY'
import zipfile, csv, io, sys, math

zip_path = '/workspace/ASE24_data_and_tools.zip'
candidate_csv = 'ASE24_data_and_tools/datasets/infoProjectsDataSet.csv'
# fallback list in case the primary path changes
fallbacks = [
    'ASE24_data_and_tools/goblinUpdater_experiments/datasets/finalDataset.csv',
    'ASE24_data_and_tools/datasets/finalDataset.csv',
    'ASE24_data_and_tools/datasets/infoProjectsDataSet.csv',
    'ASE24_data_and_tools/datasets/checkNbClonePom_infoProjectsDataSet.csv'
]

found = None
with zipfile.ZipFile(zip_path) as z:
    names = z.namelist()
    for p in [candidate_csv] + fallbacks:
        if p in names:
            found = p
            break
    if not found:
        # try to find any CSV under datasets/
        for n in names:
            if n.startswith('ASE24_data_and_tools/datasets/') and n.lower().endswith('.csv'):
                found = n
                break
    if not found:
        print("ERROR: dataset CSV not found in zip", file=sys.stderr)
        sys.exit(2)

    with z.open(found) as f:
        # read with universal newline support
        data = f.read().decode('utf-8', errors='replace')
reader = csv.DictReader(io.StringIO(data))
rows = list(reader)
if len(rows) == 0:
    print("ERROR: dataset CSV is empty", file=sys.stderr)
    sys.exit(3)

# build lowercase header map
headers = reader.fieldnames
hmap = {h.lower(): h for h in headers if h is not None}

def find_col_by_keywords(keys):
    keys = [k.lower() for k in keys]
    # exact all-keywords match
    for low, orig in hmap.items():
        if all(k in low for k in keys):
            return orig
    # any keyword match
    for low, orig in hmap.items():
        if any(k in low for k in keys):
            return orig
    return None

# heuristics for the five required metrics
col_direct = find_col_by_keywords(['direct','depend']) or find_col_by_keywords(['direct']) or find_col_by_keywords(['nb','direct'])
col_releases = find_col_by_keywords(['releas']) or find_col_by_keywords(['n_r','nr','releases'])
col_libraries = find_col_by_keywords(['librar']) or find_col_by_keywords(['n_l','nl','libraries'])
col_dep_edges = find_col_by_keywords(['dependency','edge']) or find_col_by_keywords(['dep','edge','e_d'])
col_ver_edges = find_col_by_keywords(['version','edge']) or find_col_by_keywords(['ver','edge','e_v'])

mapping = {
    " (p)'s direct dependencies": col_direct,
    "releases ((N_R))": col_releases,
    "libraries ((N_L))": col_libraries,
    "dependency edges ((E_D))": col_dep_edges,
    "versions edges ((E_V))": col_ver_edges
}

missing = [k for k,v in mapping.items() if v is None]
if missing:
    print("ERROR: Could not auto-detect columns for:", missing, file=sys.stderr)
    print("Available columns:", headers, file=sys.stderr)
    sys.exit(4)

def to_num(x):
    if x is None: return None
    x = x.strip()
    if x == '': return None
    # remove commas
    x = x.replace(',','')
    try:
        if '.' in x:
            return float(x)
        else:
            return int(x)
    except:
        try:
            return float(x)
        except:
            return None

def quantile(sorted_list, q):
    n = len(sorted_list)
    if n == 0:
        return None
    pos = q*(n-1)
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return sorted_list[lo]
    frac = pos - lo
    return sorted_list[lo] + frac*(sorted_list[hi] - sorted_list[lo])

results = []
for label, col in mapping.items():
    vals = []
    for r in rows:
        v = to_num(r.get(col, None))
        if v is not None:
            vals.append(float(v))
    vals.sort()
    if len(vals) == 0:
        q1=q2=q3=mn=mx = None
    else:
        q1 = quantile(vals, 0.25)
        q2 = quantile(vals, 0.5)
        q3 = quantile(vals, 0.75)
        mn = min(vals)
        mx = max(vals)
    results.append((label, q1, q2, q3, mn, mx))

def fmt(v):
    if v is None:
        return ''
    # if integer-valued, show as integer, else show 1 decimal if .5 else default
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    # if ends with .0, show integer
    s = ('{:.6f}'.format(v)).rstrip('0').rstrip('.')
    # For common .5 case show single decimal
    if '.' in s:
        # if one decimal enough
        parts = s.split('.')
        if len(parts[1]) == 1:
            return s
    return s

# write reproduction output
out_lines = []
out_lines.append('**Reproduced Table 2**\\n')
out_lines.append('| | Q1 | Q2 | Q3 | min | max |')
out_lines.append('| --- | ---: | ---: | ---: | ---: | ---: |')
for row in results:
    label, q1, q2, q3, mn, mx = row
    out_lines.append('|{}|{}|{}|{}|{}|{}|'.format(label, fmt(q1), fmt(q2), fmt(q3), fmt(mn), fmt(mx)))

with open('/workspace/repro.txt','w') as f:
    f.write('\\n'.join(out_lines) + '\\n')

print('WROTE /workspace/repro.txt with computed statistics for columns:')
for row in results:
    print(row[0], '->', mapping[row[0]])
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'

# make the script executable
chmod +x /workspace/repro_goblinupdater_table_2.sh

echo "Script written to /workspace/repro_goblinupdater_table_2.sh"
