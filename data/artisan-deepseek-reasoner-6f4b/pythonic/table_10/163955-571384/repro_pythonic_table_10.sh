#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 10: Reasons for using functional and procedural code**

| Reason                        | Lambdas | Comp. | MRF | Proc. |
| ----------------------------- | ------: | ----: | --: | ----: |
| Coding time                   |      ?? |    ?? |  ?? |     ? |
| Ease of use                   |       ? |    ?? |   ? |     ? |
| Maintainability               |      ?? |     ? |  ?? |     ? |
| Performance                   |       ? |    ?? |  ?? |     ? |
| Readability/Understandability |      ?? |    ?? |  ?? |    ?? |
| Size                          |      ?? |    ?? |  ?? |     — |
| Lack of knowledge             |       — |     — |   — |    ?? |
| Project constraints           |       — |     — |   — |     ? |
| Simplify debugging            |       — |     — |   — |     ? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
# Install pandas for Python script
pip install pandas openpyxl
# Extract Table 10 from the Excel file
python3 << 'PYTHON_SCRIPT'
import pandas as pd
import numpy as np

# Define the Excel file path
excel_path = '/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/working-results/RQ3ManualValidation.xlsx'

# Read the Excel file
xl = pd.ExcelFile(excel_path)

# Define the sheet names
sheets = ['Lambda', 'Comprehension', 'MRF', 'Procedural']

# Define the reason categories as per Table 10
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

# Initialize a dictionary to store counts
counts = {reason: [] for reason in reasons}

# Process each sheet
for sheet in sheets:
    df = pd.read_excel(xl, sheet_name=sheet)
    
    # Check if 'Final Classification' column exists
    if 'Final Classification' not in df.columns:
        print(f"Warning: 'Final Classification' column not found in sheet {sheet}")
        # Add zeros for all reasons for this sheet
        for reason in reasons:
            counts[reason].append(0)
        continue
    
    # Count occurrences of each reason
    for reason in reasons:
        # Count exact matches (case-sensitive as per data)
        count = (df['Final Classification'] == reason).sum()
        counts[reason].append(count)

# Create a DataFrame for the table
table_df = pd.DataFrame(counts, index=sheets).T

# Rename columns to match Table 10 format
table_df.columns = ['Lambdas', 'Comp.', 'MRF', 'Proc.']

# Reorder rows as in Table 10
table_df = table_df.loc[reasons]

# Convert to integer counts
table_df = table_df.astype(int)

# Save the table to a file
table_df.to_csv('/workspace/repro.txt', index=True)
PYTHON_SCRIPT
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
