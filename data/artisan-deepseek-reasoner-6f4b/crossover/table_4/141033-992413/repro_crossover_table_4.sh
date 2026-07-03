#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: Defect Detection Rates. For each fuzzer, we report the defect detection rate of each discovered defect across 20 fuzzing campaigns after five minutes (5M) and three hours (3H). The largest detection rate or rates (in the case of a tie) for each time and defect is highlighted in blue. Detection rates that differ significantly from Zeugma-Link's are colored red.**

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
# Section 3: Reproduction commands
cat > /workspace/generate_table4.py <<'PYEOF'
import sys
sys.path.insert(0, '/workspace/zeugma-main/zeugma-main/scripts')
import pandas as pd
import numpy as np
import tables
import report_util

# Load the detections data
data = pd.read_csv('/workspace/detections.csv')

# Convert time string to timedelta
def parse_time(t):
    if pd.isna(t):
        return pd.NaT
    # Format: '0 days 00:42:48.816000'
    try:
        return pd.to_timedelta(t)
    except:
        return pd.NaT

data['time'] = data['time'].apply(parse_time)

# Filter out rows where fuzzer is 'fuzzer' (header)
data = data[data['fuzzer'] != 'fuzzer']

# Create detection boolean for 5 minutes and 3 hours
five_min = pd.Timedelta('5 minutes')
three_hour = pd.Timedelta('3 hours')

# We need to create a DataFrame with columns: fuzzer, defect, time, detected
# For each campaign, fuzzer, defect we have a time (or NaT if not detected)
# The tables.create_defect_table expects a DataFrame with these columns

# We'll create a DataFrame with one row per (campaign_id, fuzzer, defect)
# For campaigns where defect was not detected, we set time to NaT

# First, let's get unique campaign_ids
campaign_ids = data['campaign_id'].unique()

# Create all combinations of campaign_id, fuzzer, defect
fuzzers = data['fuzzer'].unique()
defects = data['defect'].unique()

# Create an empty DataFrame with all combinations
all_combinations = []
for campaign in campaign_ids:
    for fuzzer in fuzzers:
        for defect in defects:
            all_combinations.append({
                'campaign_id': campaign,
                'fuzzer': fuzzer,
                'defect': defect
            })

all_df = pd.DataFrame(all_combinations)

# Merge with the actual data to get times
merged = pd.merge(all_df, data[['campaign_id', 'fuzzer', 'defect', 'time']], 
                  on=['campaign_id', 'fuzzer', 'defect'], how='left')

# Now create the table using the tables module
# We need to convert to the format expected by create_defect_table
# The function expects a DataFrame with columns: fuzzer, defect, time, and detected (boolean)

# We'll create detected columns for each time threshold
for threshold, label in [(five_min, '5M'), (three_hour, '3H')]:
    merged[f'detected_{label}'] = merged['time'] <= threshold

# For 5 minutes
data_5m = merged.copy()
data_5m['time'] = five_min
data_5m['detected'] = data_5m['detected_5M']

# For 3 hours
data_3h = merged.copy()
data_3h['time'] = three_hour
data_3h['detected'] = data_3h['detected_3H']

# Combine
combined_data = pd.concat([data_5m, data_3h])

# Now use the tables module to create the defect table
table = tables.create_defect_table(combined_data, [five_min, three_hour])

# Extract the styled table's data
# The table is a Styler object, we need to get the underlying data
styled_data = table.data

# Convert to markdown format
# We need to format with 2 decimal places
def format_rate(x):
    if pd.isna(x):
        return '-'
    return f"{x:.2f}"

formatted = styled_data.applymap(format_rate)

# Reorder columns to match the expected table
# The columns are multi-index: (defect, time)
# We need to flatten them
formatted.columns = [f"{col[0]} {col[1]}" for col in formatted.columns]

# Reorder rows to match expected order
fuzzer_order = ['BeDiv-Simple', 'BeDiv-Struct', 'RLCheck', 'Zest', 'Zeugma-X', 'Zeugma-1PT', 'Zeugma-2PT', 'Zeugma-Link']
formatted = formatted.reindex(fuzzer_order)

# Write to output file
with open('/workspace/repro.txt', 'w') as f:
    # Write header
    f.write("| Fuzzer       | B0 [2] 5M | B0 [2] 3H | B1 [3] 5M | B1 [3] 3H | C0 [11] 5M | C0 [11] 3H | C1 [12] 5M | C1 [12] 3H | N0 [42] 5M | N0 [42] 3H | N1 [40] 5M | N1 [40] 3H | N2 [41] 5M | N2 [41] 3H | R0 [31] 5M | R0 [31] 3H | R1 [30] 5M | R1 [30] 3H | R2 [28] 5M | R2 [28] 3H | R3 [29] 5M | R3 [29] 3H | R4 [32] 5M | R4 [32] 3H |\n")
    f.write("| ------------ | --------: | --------: | --------: | --------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |\n")
    
    for fuzzer in fuzzer_order:
        if fuzzer in formatted.index:
            row = formatted.loc[fuzzer]
            # Format each value
            values = []
            for defect in ['B0', 'B1', 'C0', 'C1', 'N0', 'N1', 'N2', 'R0', 'R1', 'R2', 'R3', 'R4']:
                for time in ['5M', '3H']:
                    col_name = f"{defect} {time}"
                    if col_name in row:
                        val = row[col_name]
                        if val == '-':
                            values.append(f"      {val}")
                        else:
                            values.append(f"      {val}")
                    else:
                        values.append("      ?.??")
            
            line = f"| {fuzzer:13}"
            for val in values:
                line += f" |{val:>9}"
            line += " |\n"
            f.write(line)
PYEOF

# Run the Python script in the Docker container
docker exec d3fd43a2e84bb88421cd632fc6b58d5b97a52ef857f0c2ea57e71e3af30cfe8c python3 /workspace/generate_table4.py

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
