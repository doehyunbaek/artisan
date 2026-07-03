#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**

|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |
| -------- | :---------: | :-----------------------: | :----------------------: |
| ReCDroid |      ??     |             ??            |            ??            |
| Yakusu   |      ?      |             ??            |             ?            |
| Roam     |      ??     |             ??            |            ??            |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/11068809
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /tmp/compute_table3.py <<'SCRIPTEOF'
import subprocess
import sys

# Convert PDF to markdown
result = subprocess.run(
    ['uvx', '--from', 'pymupdf4llm', 'python', '-c', 
     'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))', 
     'ROAM-Artifact/ROAM-Artifact/Evaluation/results.pdf'],
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print("Error converting PDF")
    sys.exit(1)

markdown = result.stdout
lines = markdown.split('\n')

# Find the start of the data table
table_start = None
for i, line in enumerate(lines):
    if line.startswith('|1|'):
        table_start = i
        break

if table_start is None:
    print("Error: Could not find table start")
    sys.exit(1)

# Parse all 72 rows
data = []
for i in range(table_start, table_start + 72):
    line = lines[i]
    if not line.startswith('|'):
        continue
    
    parts = line.strip('|').split('|')
    
    try:
        missing_steps = int(parts[5].strip())  # # Missing Steps at index 5
        
        # Roam reproduction result at index 7
        roam_result = parts[7].strip().lower()
        
        # ReCDroid reproduction result at index 24
        recdroid_result = parts[24].strip().lower()
        
        # Yakusu reproduction result at index 55 (based on analysis)
        yakusu_result = parts[55].strip().lower()
        
        data.append({
            'missing_steps': missing_steps,
            'roam_success': 1 if roam_result == 'success' else 0,
            'recdroid_success': 1 if recdroid_result == 'success' else 0,
            'yakusu_success': 1 if yakusu_result == 'success' else 0
        })
    except (IndexError, ValueError) as e:
        print(f"Error parsing line: {e}")
        continue

# Initialize counters
counters = {
    'all': {'total': 0, 'roam': 0, 'recdroid': 0, 'yakusu': 0},
    'without_missing': {'total': 0, 'roam': 0, 'recdroid': 0, 'yakusu': 0},
    'with_missing': {'total': 0, 'roam': 0, 'recdroid': 0, 'yakusu': 0}
}

# Process all data
for row in data:
    counters['all']['total'] += 1
    counters['all']['roam'] += row['roam_success']
    counters['all']['recdroid'] += row['recdroid_success']
    counters['all']['yakusu'] += row['yakusu_success']
    
    if row['missing_steps'] == 0:
        counters['without_missing']['total'] += 1
        counters['without_missing']['roam'] += row['roam_success']
        counters['without_missing']['recdroid'] += row['recdroid_success']
        counters['without_missing']['yakusu'] += row['yakusu_success']
    else:
        counters['with_missing']['total'] += 1
        counters['with_missing']['roam'] += row['roam_success']
        counters['with_missing']['recdroid'] += row['recdroid_success']
        counters['with_missing']['yakusu'] += row['yakusu_success']

# Calculate percentages
def calculate_percentage(success, total):
    return round((success / total) * 100, 1) if total > 0 else 0.0

results = {
    'roam': {
        'all': calculate_percentage(counters['all']['roam'], counters['all']['total']),
        'without_missing': calculate_percentage(counters['without_missing']['roam'], counters['without_missing']['total']),
        'with_missing': calculate_percentage(counters['with_missing']['roam'], counters['with_missing']['total'])
    },
    'recdroid': {
        'all': calculate_percentage(counters['all']['recdroid'], counters['all']['total']),
        'without_missing': calculate_percentage(counters['without_missing']['recdroid'], counters['without_missing']['total']),
        'with_missing': calculate_percentage(counters['with_missing']['recdroid'], counters['with_missing']['total'])
    },
    'yakusu': {
        'all': calculate_percentage(counters['all']['yakusu'], counters['all']['total']),
        'without_missing': calculate_percentage(counters['without_missing']['yakusu'], counters['without_missing']['total']),
        'with_missing': calculate_percentage(counters['with_missing']['yakusu'], counters['with_missing']['total'])
    }
}

# Output the table
with open('/workspace/repro.txt', 'w') as f:
    f.write("**Table 3: Reproduction Rate of Each Approach (Shown as a Percent)**\n\n")
    f.write("|          | All Reports | Reports w/o Missing Steps | Reports w/ Missing Steps |\n")
    f.write("| -------- | :---------: | :-----------------------: | :----------------------: |\n")
    f.write(f"| ReCDroid |     {results['recdroid']['all']:.1f}     |           {results['recdroid']['without_missing']:.1f}          |           {results['recdroid']['with_missing']:.1f}          |\n")
    f.write(f"| Yakusu   |     {results['yakusu']['all']:.1f}      |           {results['yakusu']['without_missing']:.1f}          |           {results['yakusu']['with_missing']:.1f}           |\n")
    f.write(f"| Roam     |     {results['roam']['all']:.1f}     |           {results['roam']['without_missing']:.1f}          |           {results['roam']['with_missing']:.1f}          |\n")
SCRIPTEOF

python3 /tmp/compute_table3.py
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
