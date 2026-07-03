#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**

**Lambda (90 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 2.29 |     0.83 |     0.31 |    2.65 |    0.02 |
| Compl.      | 0.88 |    -0.13 |     0.18 |   -0.73 |    0.47 |

**Comprehension (120 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 1.49 |     0.40 |     0.22 |    1.84 |    0.07 |
| Compl.      | 0.77 |    -0.26 |     0.11 |   -2.27 |    0.05 |

**MRF (103 data points)**

| Term        |   OR | Estimate | StdError | t-value | p-value |
| ----------- | ---: | -------: | -------: | ------: | ------: |
| Usage Freq. | 1.79 |     0.58 |     0.25 |    2.31 |    0.02 |

EOTABLE
# Section 2: Artifact download
echo "Downloading artifact from Zenodo..."
curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip" -o /workspace/artifact.zip 2>&1
echo "Extracting artifact..."
unzip -q /workspace/artifact.zip -d /workspace/artifact 2>&1
# Section 3: Reproduction commands (populate from reviewed steps)
echo "Running statistical analysis..."
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts
sh run-analysis.sh 2>&1 | tail -5
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the reproduced table using Python script
cat > /workspace/format_table.py <<'EOF'
#!/usr/bin/env python3
import csv
import os

def format_float(x):
    return f"{x:.2f}"

def read_lambda_csv(path):
    rows = []
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows

def read_mrf_csv(path):
    with open(path, 'r') as f:
        lines = [line.strip() for line in f.readlines()]
    row = {
        'OR': lines[1],
        'Value': lines[2],
        'Std. Error': lines[3],
        't value': lines[4],
        'p value': lines[5]
    }
    return [row]

def main():
    base_dir = "/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results"
    lambda_rows = read_lambda_csv(os.path.join(base_dir, "Table-9-rq2-lambda.csv"))
    comp_rows = read_lambda_csv(os.path.join(base_dir, "Table-9-rq2-comp.csv"))
    mrf_rows = read_mrf_csv(os.path.join(base_dir, "Table-9-rq2-mrf.csv"))
    
    sections = [
        ("Lambda", lambda_rows, "90 data points"),
        ("Comprehension", comp_rows, "120 data points"),
        ("MRF", mrf_rows, "103 data points")
    ]
    
    print("**Table 9: RQ2: Ordinal logistic regression results of the relationship between perceived understandability of the functional constructs and (i) participants’ usage frequency, and (ii) constructs’ complexity (except for MRF)**")
    print()
    
    for section_name, rows, data_points in sections:
        print(f"**{section_name} ({data_points})**")
        print()
        print("| Term        |   OR | Estimate | StdError | t-value | p-value |")
        print("| ----------- | ---: | -------: | -------: | ------: | ------: |")
        
        term_labels = ["Usage Freq.", "Compl."] if section_name != "MRF" else ["Usage Freq."]
        for i, row in enumerate(rows):
            label = term_labels[i]
            or_val = float(row['OR'])
            est = float(row['Value'])
            std = float(row['Std. Error'])
            tval = float(row['t value'])
            pval = float(row['p value'])
            
            or_fmt = format_float(or_val)
            est_fmt = format_float(est)
            std_fmt = format_float(std)
            t_fmt = format_float(tval)
            p_fmt = format_float(pval)
            
            print(f"| {label:11} | {or_fmt:>4} | {est_fmt:>8} | {std_fmt:>8} | {t_fmt:>7} | {p_fmt:>7} |")
        print()

if __name__ == "__main__":
    main()
EOF
python3 /workspace/format_table.py
echo '</artisan_submit>'