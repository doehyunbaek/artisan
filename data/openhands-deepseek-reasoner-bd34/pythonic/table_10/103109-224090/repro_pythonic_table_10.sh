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

# Section 2: Artifact download
echo "Downloading artifact from Zenodo..."
curl -s -L -o /workspace/artifact.zip https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content
echo "Extracting artifact..."
unzip -q /workspace/artifact.zip -d /workspace/artifact

# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running reproduction analysis..."
cat > /workspace/compute_table10.py <<'PYSCRIPT'
#!/usr/bin/env python3
"""
Reproduce Table 10 from the paper.
Counts reasons for using functional and procedural code from the manual validation Excel file.
"""
import openpyxl
from collections import Counter
import sys

def count_classifications(sheet_name, mapping=None):
    """Return Counter of classifications for given sheet."""
    wb = openpyxl.load_workbook('/workspace/artifact/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx', data_only=True)
    ws = wb[sheet_name]
    # Find header row
    headers = []
    for row in ws.iter_rows(min_row=1, max_row=1, values_only=True):
        headers = list(row)
        break
    # Determine column index of 'Final Classification'
    col_idx = None
    for i, h in enumerate(headers):
        if h and 'Classification' in str(h):
            col_idx = i + 1
            break
    if col_idx is None:
        raise ValueError(f'Final Classification column not found in sheet {sheet_name}')
    # Collect classifications
    classifications = []
    for row in ws.iter_rows(min_row=2, values_only=False):  # skip header
        cell = row[col_idx - 1]
        val = cell.value
        if val and str(val).strip().lower() != 'none':
            raw = str(val).strip()
            if mapping and raw in mapping:
                classifications.append(mapping[raw])
            else:
                classifications.append(raw)
    return Counter(classifications)

def main():
    # Mapping for procedural sheet variations
    proc_mapping = {
        'Debugging is easier': 'Simplify debugging',
        'lack of knowledge': 'Lack of knowledge',
        'Lack of knowledge': 'Lack of knowledge',
        'Project Constraint': 'Project constraints',
        'Project constraint': 'Project constraints',
    }
    
    sheets = ['Lambda', 'Comprehension', 'MRF', 'Procedural']
    all_counts = {}
    for sheet in sheets:
        if sheet == 'Procedural':
            all_counts[sheet] = count_classifications(sheet, proc_mapping)
        else:
            all_counts[sheet] = count_classifications(sheet)
    
    # Define expected reasons order (as in Table 10)
    reasons = [
        'Coding time',
        'Ease of use',
        'Maintainability',
        'Performance',
        'Readability/Understandability',
        'Size',
        'Lack of knowledge',
        'Project constraints',
        'Simplify debugging'
    ]
    
    # Map sheet names to table columns
    column_map = {
        'Lambda': 'Lambdas',
        'Comprehension': 'Comp.',
        'MRF': 'MRF',
        'Procedural': 'Proc.'
    }
    
    # Build table rows
    table = []
    for reason in reasons:
        row = [reason]
        for sheet in sheets:
            count = all_counts[sheet].get(reason, 0)
            row.append(count)
        table.append(row)
    
    # Output markdown table
    output = []
    output.append("**Table 10: Reasons for using functional and procedural code**")
    output.append("")
    header = "| Reason | " + " | ".join([column_map[s] for s in sheets]) + " |"
    separator = "| " + " | ".join(["---" for _ in range(len(sheets)+1)]) + " |"
    output.append(header)
    output.append(separator)
    for row in table:
        formatted = [row[0]] + [str(c) if c != 0 else "—" for c in row[1:]]
        output.append("| " + " | ".join(formatted) + " |")
    
    # Print to stdout
    sys.stdout.write("\n".join(output) + "\n")
    
    # Also write raw counts to stderr for debugging
    sys.stderr.write("\nRaw counts:\n")
    for sheet in sheets:
        sys.stderr.write(f"\n{sheet}:\n")
        for reason, count in sorted(all_counts[sheet].items()):
            sys.stderr.write(f"  {reason}: {count}\n")

if __name__ == '__main__':
    main()
PYSCRIPT

python /workspace/compute_table10.py > /workspace/repro.txt 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'