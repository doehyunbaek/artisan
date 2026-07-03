#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Evaluation Results**

| Project Name          | Summary                                                                                | Annotations | Total Warnings |
| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |
| MarginSwap            | Dex project for margin trading on Uniswap and Sushiswap                                |           ? |              ? |
| Vader Protocol        | Yield project for a collateralized stablecoin                                          |          ?? |              ? |
| PoolTogether          | Gaming service on yield interest                                                       |          ?? |              ? |
| Tracer                | Derivative project that supports perpetual markets                                     |          ?? |              ? |
| Yield Micro           | Lending project supporting borrowing, lending, and liquidity                           |           ? |              ? |
| Sushi Trident         | Dex project for deploying personalized liquidity markets                               |          ?? |              ? |
| yAxis                 | Yield project where users’ aggregated funds are used in strategies for yield           |           ? |              ? |
| Badger Dao            | Yield project                                                                          |           ? |              ? |
| Wild Credit           | Lending project relying on pairs of assets instead of a pool                           |          ?? |              ? |
| PoolTogether v4       | Gaming service on yield interest                                                       |           ? |              ? |
| Sushi Trident p2      | Dex project for deploying personalized liquidity markets                               |          ?? |             ?? |
| Swell                 | Yield project that uses set orders for Yield claiming                                  |           ? |              ? |
| Covalent              | Users delegate commissions to a Validators, which stakes the funds for interest        |           ? |              ? |
| yAxis p2              | Yield project where users’ aggregated funds are used in strategies for yield           |           ? |              ? |
| Perennial             | Derivative project supporting synthetic token perpetual markets                        |           ? |              ? |
| Yeti Finance          | Lending project made against a contract specific token                                 |           ? |              ? |
| Vader Protocol p3     | Yield project for a collateralized stablecoin                                          |           ? |              ? |
| InsureDao             | Insurance markets where buyers pay premium for protection against losses               |          ?? |              ? |
| Rocket Joe            | Dex project where users exchange funds in return for new project liquidity             |           ? |              ? |
| Concur Finance        | Yield project                                                                          |           ? |              ? |
| Biconomy Hyphen       | Cross Chain project where users can deposit and withdraw for pools on different chains |           ? |              ? |
| Volt                  | Dex project which conserves the value of user funds against inflation                  |           ? |              ? |
| Badger Dao p3         | Yield project                                                                          |           ? |              ? |
| Tigris Trade          | Dex project utilizing off-chain oracles to provide real-time prices                    |          ?? |              ? |
| **Total**             |                                                                                        |             |             ?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10449162
# Section 3: Reproduction commands
echo "Pulling Docker image and starting container..."
docker pull icse24sctype/full:latest > /dev/null 2>&1
container_id=$(docker run -d --init --entrypoint bash icse24sctype/full:latest -c 'sleep infinity')
sleep 10
echo "Running test_benchmark_final.sh inside container..."
docker exec "$container_id" /bin/bash --noprofile --norc -c "./test_benchmark_final.sh 2>&1" > /tmp/full_output.txt
# Parse the output to extract annotation counts and warnings
cat > /tmp/parse_table3.py <<'PYEOF'
import re

# Read the output file
with open('/tmp/full_output.txt', 'r') as f:
    content = f.read()

# Split into lines for easier processing
lines = content.split('\n')

# Define the order of projects as in Table 3
table_projects = [
    "MarginSwap", "Vader Protocol", "PoolTogether", "Tracer",
    "Yield Micro", "Sushi Trident", "yAxis", "Badger Dao",
    "Wild Credit", "PoolTogether v4", "Sushi Trident p2",
    "Swell", "Covalent", "yAxis p2", "Perennial", "Yeti Finance",
    "Vader Protocol p3", "InsureDao", "Rocket Joe", "Concur Finance",
    "Biconomy Hyphen", "Volt", "Badger Dao p3", "Tigris Trade"
]

# Mapping from output project names to table names
output_to_table = {
    "MarginSwap": "MarginSwap",
    "Vader Protocol P1": "Vader Protocol",
    "PoolTogether": "PoolTogether",
    "Tracer": "Tracer",
    "Yield Micro": "Yield Micro",
    "Sushi Tridnet": "Sushi Trident",
    "yAxis": "yAxis",
    "BadgerDao": "Badger Dao",
    "Wild Credit": "Wild Credit",
    "Pool Together v4": "PoolTogether v4",
    "Sushi Trident": "Sushi Trident p2",
    "Swivel": "Swell",
    "Covalent": "Covalent",
    "yAxis p2": "yAxis p2",
    "Perennial": "Perennial",
    "Yeti Finance": "Yeti Finance",
    "Vader Protocol p3": "Vader Protocol p3",
    "InsureDao": "InsureDao",
    "Rocket Joe": "Rocket Joe",
    "Concur Finance": "Concur Finance",
    "Biconomy Hyphen": "Biconomy Hyphen",
    "Volt": "Volt",
    "Badger Dao p3": "Badger Dao p3",
    "Tigris Trade": "Tigris Trade"
}

# Initialize dictionaries
annotations = {}
warnings = {}

# Process lines to find annotation counts and warnings
current_annotations = 0
for i, line in enumerate(lines):
    # Check for annotation count
    ann_match = re.search(r'Annotation count:\s*(\d+)', line)
    if ann_match:
        current_annotations = int(ann_match.group(1))
    
    # Check for warning line
    warn_match = re.search(r'\[\*\] Tested\s+(\d+)\s+warnings for\s+(.+)', line)
    if warn_match:
        warn_count = int(warn_match.group(1))
        project_name = warn_match.group(2).strip()
        # Map to table name
        table_name = output_to_table.get(project_name)
        if table_name:
            annotations[table_name] = current_annotations
            warnings[table_name] = warn_count
            # Reset current_annotations to avoid reuse
            current_annotations = 0
        else:
            # Some warnings are for parts we ignore (e.g., "Part 1", "Badger Dao p2")
            pass

# Ensure all projects have entries
for proj in table_projects:
    if proj not in annotations:
        annotations[proj] = 0
    if proj not in warnings:
        warnings[proj] = 0

# Calculate totals
total_annotations = sum(annotations.values())
total_warnings = sum(warnings.values())

# Summary texts (from expected table)
summaries = [
    "Dex project for margin trading on Uniswap and Sushiswap",
    "Yield project for a collateralized stablecoin",
    "Gaming service on yield interest",
    "Derivative project that supports perpetual markets",
    "Lending project supporting borrowing, lending, and liquidity",
    "Dex project for deploying personalized liquidity markets",
    "Yield project where users’ aggregated funds are used in strategies for yield",
    "Yield project",
    "Lending project relying on pairs of assets instead of a pool",
    "Gaming service on yield interest",
    "Dex project for deploying personalized liquidity markets",
    "Yield project that uses set orders for Yield claiming",
    "Users delegate commissions to a Validators, which stakes the funds for interest",
    "Yield project where users’ aggregated funds are used in strategies for yield",
    "Derivative project supporting synthetic token perpetual markets",
    "Lending project made against a contract specific token",
    "Yield project for a collateralized stablecoin",
    "Insurance markets where buyers pay premium for protection against losses",
    "Dex project where users exchange funds in return for new project liquidity",
    "Yield project",
    "Cross Chain project where users can deposit and withdraw for pools on different chains",
    "Dex project which conserves the value of user funds against inflation",
    "Yield project",
    "Dex project utilizing off-chain oracles to provide real-time prices"
]

# Generate markdown table
table_lines = []
table_lines.append("**Table 3: Evaluation Results**")
table_lines.append("")
table_lines.append("| Project Name          | Summary                                                                                | Annotations | Total Warnings |")
table_lines.append("| --------------------- | -------------------------------------------------------------------------------------- | ----------: | -------------: |")

for idx, proj in enumerate(table_projects):
    ann = annotations[proj]
    warn = warnings[proj]
    summary = summaries[idx] if idx < len(summaries) else ""
    # Format with fixed widths for alignment
    table_lines.append(f"| {proj:22} | {summary:81} | {ann:11} | {warn:14} |")

table_lines.append(f"| **Total**             |                                                                                        | {total_annotations:11} | {total_warnings:14} |")

# Write to file
with open('/workspace/repro.txt', 'w') as f:
    f.write("\n".join(table_lines))
PYEOF
python3 /tmp/parse_table3.py
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
