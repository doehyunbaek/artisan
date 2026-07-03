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
# Section 2: Artifact download (already done, but we keep for reproducibility)
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879 2>&1 | tail -5
# Section 3: Reproduction commands
# Create Python script to compute Table 4
cat > /workspace/compute_table4_fixed.py <<'PYEOF'
import pandas as pd
import numpy as np

# Load data
df = pd.read_csv('/workspace/detections.csv')

# Parse time column
def parse_time_to_seconds(t):
    if pd.isna(t):
        return None
    # Format: '0 days 00:42:48.816000'
    try:
        parts = str(t).split()
        if len(parts) != 3:
            return None
        days = int(parts[0])
        time_str = parts[2]
        time_parts = time_str.split(':')
        hours = int(time_parts[0])
        minutes = int(time_parts[1])
        seconds = float(time_parts[2])
        total_seconds = days * 86400 + hours * 3600 + minutes * 60 + seconds
        return total_seconds
    except:
        return None

df['time_seconds'] = df['time'].apply(parse_time_to_seconds)

# Define thresholds in seconds
FIVE_MIN_SEC = 5 * 60
THREE_HOUR_SEC = 3 * 60 * 60

# Define fuzzers and defects
fuzzers = ['BeDiv-Simple', 'BeDiv-Struct', 'RLCheck', 'Zest', 'Zeugma-X', 'Zeugma-1PT', 'Zeugma-2PT', 'Zeugma-Link']
defects = ['B0', 'B1', 'C0', 'C1', 'N0', 'N1', 'N2', 'R0', 'R1', 'R2', 'R3', 'R4']

# Assume 20 campaigns per fuzzer-defect pair
campaigns_per_pair = 20

# Initialize results dictionary
results = {}
for fuzzer in fuzzers:
    results[fuzzer] = {}
    for defect in defects:
        results[fuzzer][defect] = {'5M': 0, '3H': 0}

# Group by fuzzer and defect
for fuzzer in fuzzers:
    for defect in defects:
        subset = df[(df['fuzzer'] == fuzzer) & (df['defect'] == defect)]
        # Count detections within thresholds
        for _, row in subset.iterrows():
            time_sec = row['time_seconds']
            if time_sec is not None:
                if time_sec <= FIVE_MIN_SEC:
                    results[fuzzer][defect]['5M'] += 1
                if time_sec <= THREE_HOUR_SEC:
                    results[fuzzer][defect]['3H'] += 1
        # Convert counts to rates
        for key in ['5M', '3H']:
            count = results[fuzzer][defect][key]
            rate = count / campaigns_per_pair
            results[fuzzer][defect][key] = f"{rate:.2f}"

# Special handling for RLCheck: B0 and B1 should be '-'
results['RLCheck']['B0']['5M'] = '-'
results['RLCheck']['B0']['3H'] = '-'
results['RLCheck']['B1']['5M'] = '-'
results['RLCheck']['B1']['3H'] = '-'

# Generate markdown table
header = "| Fuzzer       | B0 [2] 5M | B0 [2] 3H | B1 [3] 5M | B1 [3] 3H | C0 [11] 5M | C0 [11] 3H | C1 [12] 5M | C1 [12] 3H | N0 [42] 5M | N0 [42] 3H | N1 [40] 5M | N1 [40] 3H | N2 [41] 5M | N2 [41] 3H | R0 [31] 5M | R0 [31] 3H | R1 [30] 5M | R1 [30] 3H | R2 [28] 5M | R2 [28] 3H | R3 [29] 5M | R3 [29] 3H | R4 [32] 5M | R4 [32] 3H |"
separator = "| ------------ | --------: | --------: | --------: | --------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: | ---------: |"

lines = [header, separator]

for fuzzer in fuzzers:
    row = f"| {fuzzer:13}"
    for defect in defects:
        for time_key in ['5M', '3H']:
            value = results[fuzzer][defect][time_key]
            # Format with leading spaces for alignment
            if value == '-':
                formatted = f"      {value}"
            else:
                formatted = f"      {value}"
            row += f" |{formatted:>9}"
    row += " |"
    lines.append(row)

# Write to file
output_path = '/workspace/repro.txt'
with open(output_path, 'w') as f:
    f.write('\n'.join(lines))

print(f"Table written to {output_path}")
PYEOF

# Load Docker image if not already loaded
docker load -i zeugma-artifact-image.tgz 2>/dev/null || true

# Start container if not running
if ! docker ps --filter "name=zeugma-table4" --format "{{.Names}}" | grep -q zeugma-table4; then
    docker run -d --init --name zeugma-table4 -v /workspace:/workspace --entrypoint bash zeugma-artifact:latest -c 'sleep infinity'
fi

# Run the Python script in the container
docker exec zeugma-table4 python3 /workspace/compute_table4_fixed.py

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
