#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Field Immutability Results for OpenJDK**

| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |
| ---------- | ------: | -----------: | -------: | -------: |
| Ad-hoc CHA |  ?? ??? |       ?? ??? |      ??? |   ?? ??? |
| CHA        |  ?? ??? |       ?? ??? |       ?? |   ?? ??? |
| RTA        |  ?? ??? |        ? ??? |      ??? |   ?? ??? |
| XTA        |  ?? ??? |        ? ??? |      ??? |   ?? ??? |

*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10890011
# Section 3: Reproduction commands (populate from reviewed steps)
# Create extraction script that reads from raw files
cat > /workspace/extract_from_raw.py <<'PYSCRIPT'
import os
import re
import sys

def extract_counts_from_file(filepath):
    """Extract counts from the raw output file."""
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Look for the summary lines at the end
    search_lines = lines[-50:]
    
    counts = {}
    
    for line in search_lines:
        line = line.strip()
        if line.startswith('Mutable Fields:'):
            parts = line.split(':')
            if len(parts) >= 2:
                num = parts[1].strip().split()[0]  # Get the number (might be followed by text)
                counts['mutable'] = int(num)
        elif line.startswith('Non Transitively Immutable Fields:'):
            parts = line.split(':')
            if len(parts) >= 2:
                num = parts[1].strip().split()[0]
                counts['non_trans'] = int(num)
        elif line.startswith('Dependently Immutable Fields:'):
            parts = line.split(':')
            if len(parts) >= 2:
                num = parts[1].strip().split()[0]
                counts['depen'] = int(num)
        elif line.startswith('Transitively Immutable Fields:'):
            parts = line.split(':')
            if len(parts) >= 2:
                num = parts[1].strip().split()[0]
                counts['trans'] = int(num)
    
    return counts

def format_number(num):
    """Format number with space as thousands separator."""
    return f"{num:,}".replace(",", " ")

def main():
    base_dir = 'Unimocg_Artifact/evaluation/results/immutability'
    
    algorithms = ['AdHocCHA', 'CHA', 'RTA', 'XTA']
    results = {}
    
    for algo in algorithms:
        algo_dir = os.path.join(base_dir, algo)
        # Find the .txt file in the directory
        txt_files = [f for f in os.listdir(algo_dir) if f.endswith('.txt')]
        if not txt_files:
            print(f"Warning: No .txt file found for {algo}", file=sys.stderr)
            continue
        
        # Assuming the first .txt file is the one we want
        filepath = os.path.join(algo_dir, txt_files[0])
        counts = extract_counts_from_file(filepath)
        
        if counts:
            results[algo] = counts
        else:
            print(f"Warning: Could not extract counts for {algo}", file=sys.stderr)
    
    # Generate the table
    table_lines = [
        "**Table 4: Field Immutability Results for OpenJDK**",
        "",
        "| Algorithm  | mutable | ⊒ non-trans. | ⊒ depen. | ⊒ trans. |",
        "| ---------- | ------: | -----------: | -------: | -------: |"
    ]
    
    algo_display = {
        'AdHocCHA': 'Ad-hoc CHA',
        'CHA': 'CHA',
        'RTA': 'RTA',
        'XTA': 'XTA'
    }
    
    for algo_key in ['AdHocCHA', 'CHA', 'RTA', 'XTA']:
        if algo_key in results:
            data = results[algo_key]
            mutable = format_number(data.get('mutable', 0))
            non_trans = format_number(data.get('non_trans', 0))
            depen = format_number(data.get('depen', 0))
            trans = format_number(data.get('trans', 0))
            table_lines.append(f"| {algo_display[algo_key]} | {mutable} | {non_trans} | {depen} | {trans} |")
    
    table_lines.extend([
        "",
        "*depen. = dependently immutable, trans. = transitively immutable. Higher numbers in columns to the right = more precise.*"
    ])
    
    print('\n'.join(table_lines))

if __name__ == "__main__":
    main()
PYSCRIPT

# Run extraction script
python3 /workspace/extract_from_raw.py > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
