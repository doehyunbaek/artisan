docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash

# 1. Download and Extract
curl -L -o artifact_efficient_test_interference_detection_c.tgz "https://zenodo.org/records/13767954/files/artifact_efficient_test_interference_detection_c.tgz?download=1"
tar xvf artifact_efficient_test_interference_detection_c.tgz > /dev/null

# 2. Merge CSVs Eloquently
# NR==1 keeps the first header. FNR>1 keeps data rows from all files.
find -name "*-testsuite-permutation-data.csv" -exec awk 'NR==1 || FNR>1' {} + > /workspace/temp_tsp_data.csv

# 3. Create Python Script
cat << 'EOFEOF' > /workspace/process_table.py
import csv
import math

def format_tsp(val_str):
    """Formats large integers into scientific notation."""
    try:
        val = int(val_str)
        if val > 99999999:
            exponent = int(math.floor(math.log10(abs(val))))
            mantissa = val / (10**exponent)
            return f"{mantissa:.2f}×10^{exponent}"
        return str(val)
    except ValueError:
        return val_str

# Read all rows into memory
data = []
with open('/workspace/temp_tsp_data.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        data.append(row)

# Sort alphabetically by project name
data.sort(key=lambda x: x['project'])

# Print Header
print("| Project | TSP Max | TSP OFSFDF |")
print("| :--- | :--- | :--- |")

# Print Sorted Rows
for row in data:
    project = row['project'].strip()
    tsp_max = format_tsp(row.get('tsp_max', '0'))
    tsp_ofsfdf = format_tsp(row.get('tsp_ofsfdf', '0'))
    print(f"| {project} | {tsp_max} | {tsp_ofsfdf} |")
EOFEOF

python3 /workspace/process_table.py > /workspace/repro.txt
cat /workspace/repro.txt
EOF