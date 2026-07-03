#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 10: Reasons for using functional and procedural code**

| Reason                        | Lambdas | Comp. | MRF | Proc. |
| ----------------------------- | ------: | ----: | --: | ----: |
| Coding time                   |      11 |    12 |  10 |     2 |
| Ease of use                   |       4 |    10 |   8 |     7 |
| Maintainability               |      14 |     9 |  14 |     6 |
| Performance                   |       7 |    28 |  23 |     6 |
| Readability/Understandability |      19 |    89 |  33 |    27 |
| Size                          |      41 |    76 |  39 |     — |
| Lack of knowledge             |       — |     — |   — |    16 |
| Project constraints           |       — |     — |   — |     5 |
| Simplify debugging            |       — |     — |   — |     9 |

EOTABLE

# Section 2: Artifact download (if needed)
if [ ! -f /workspace/ICSE2024-funcConstructs-Artifacts.zip ]; then
  curl -L -o /workspace/ICSE2024-funcConstructs-Artifacts.zip 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content'
fi
mkdir -p /workspace/ICSE2024
unzip -o /workspace/ICSE2024-funcConstructs-Artifacts.zip -d /workspace/ICSE2024 >/dev/null 2>&1 || true

# Section 3: Reproduction commands
# Convert RQ3 manual validation workbook sheets to CSV (try common sheet name variants)
XLSX="/workspace/ICSE2024/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx"
for s in lambda comprehension mrf procedural Lambda Comprehension Mrf Procedural; do
  uvx --from csvkit in2csv -s "$s" "$XLSX" > /workspace/"$s".csv 2>/dev/null || true
done

# Parse extracted CSVs and count occurrences of "Final Classification" values.
python3 - <<'PY'
import csv,os,collections
sheets=['lambda','comprehension','mrf','procedural','Lambda','Comprehension','Mrf','Procedural']
# Target reasons in the order requested
reasons = ["Coding time","Ease of use","Maintainability","Performance","Readability/Understandability","Size","Lack of knowledge","Project constraints","Simplify debugging"]
# Counters per column requested (Lambdas, Comp., MRF, Proc.)
counts = {'Lambda':collections.Counter(),'Comp.':collections.Counter(),'MRF':collections.Counter(),'Proc.':collections.Counter()}
for s in sheets:
    p=f'/workspace/{s}.csv'
    if not os.path.exists(p): continue
    try:
        with open(p,newline='',encoding='utf-8') as f:
            reader=csv.DictReader(f)
            # try finding a "Final Classification" header (case-insensitive)
            key=None
            for h in (reader.fieldnames or []):
                if h and 'final' in h.lower() and 'class' in h.lower():
                    key=h
                    break
            if not key:
                # fallback: use last column
                if reader.fieldnames:
                    key=reader.fieldnames[-1]
                else:
                    continue
            for row in reader:
                raw = row.get(key,'') or ''
                val = raw.strip()
                if not val or val.lower()=='none':
                    continue
                # take first part if multiple categories provided
                v = val.split(';')[0].split(',')[0].strip()
                if s.lower().startswith('lambda'):
                    dest='Lambda'
                elif s.lower().startswith('comprehension'):
                    dest='Comp.'
                elif s.lower().startswith('mrf'):
                    dest='MRF'
                else:
                    dest='Proc.'
                counts[dest][v]+=1
    except Exception as e:
        # ignore parse issues and continue
        continue

# Write a reproducible CSV-style table to /workspace/repro.txt
out_lines=[]
out_lines.append("Reason,Lambdas,Comp.,MRF,Proc.")
for r in reasons:
    l = counts['Lambda'].get(r,0)
    c = counts['Comp.'].get(r,0)
    m = counts['MRF'].get(r,0)
    p = counts['Proc.'].get(r,0)
    # Represent missing entries as "—" only if all are zero for that reason in functional columns and procedural is expected non-zero? Keep numeric zeros otherwise.
    out_lines.append(f"{r},{l},{c},{m},{p}")
with open('/workspace/repro.txt','w',encoding='utf-8') as of:
    of.write('\n'.join(out_lines))
print("WROTE /workspace/repro.txt")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'
