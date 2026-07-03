#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: The Match Accuracy and Reproduction Rate for RQ5**

|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |
| --------- | :---------------------: | :-------------------: |
| Roam-Sim  |            88           |           65          |
| Roam-Dist |            77           |           38          |
| Roam      |            93           |           94          |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o ROAM-Artifact.zip "https://zenodo.org/api/records/11068809/files/ROAM-Artifact.zip/content"
unzip -o ROAM-Artifact.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ROAM-Artifact
# Convert results PDF to markdown for parsing
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' Evaluation/results.pdf 2>/dev/null > /workspace/results.md
# Compute averages and produce table
cat > /workspace/compute_table5_final.py <<'PYEOF'
import sys, re

def parse_markdown_table(md_text):
    lines = md_text.strip().split('\n')
    table_rows = [line.strip() for line in lines if line.strip().startswith('|')]
    if len(table_rows) < 2:
        return None
    data_rows = []
    for row in table_rows:
        if re.match(r'^\|[-:\s|]+\|$', row):
            continue
        data_rows.append(row)
    parsed = []
    for row in data_rows:
        cells = [cell.strip() for cell in row.split('|') if cell.strip() != '']
        parsed.append(cells)
    return parsed

def compute_averages(table_data):
    # Indices from the markdown structure (0-based)
    roam_match_idx = 6
    roam_repro_idx = 7
    sim_match_idx = 12
    sim_repro_idx = 13
    dist_match_idx = 15
    dist_repro_idx = 16
    
    roam_match_vals = []
    roam_repro_success = 0
    sim_match_vals = []
    sim_repro_success = 0
    dist_match_vals = []
    dist_repro_success = 0
    total = 0
    
    for row in table_data[2:]:
        if len(row) < max(roam_match_idx, roam_repro_idx, sim_match_idx, sim_repro_idx, dist_match_idx, dist_repro_idx) + 1:
            continue
        total += 1
        try:
            roam_match = float(row[roam_match_idx]) if row[roam_match_idx] else 0.0
            roam_match_vals.append(roam_match)
        except:
            roam_match_vals.append(0.0)
        try:
            sim_match = float(row[sim_match_idx]) if row[sim_match_idx] else 0.0
            sim_match_vals.append(sim_match)
        except:
            sim_match_vals.append(0.0)
        try:
            dist_match = float(row[dist_match_idx]) if row[dist_match_idx] else 0.0
            dist_match_vals.append(dist_match)
        except:
            dist_match_vals.append(0.0)
        
        roam_repro = row[roam_repro_idx].strip().lower()
        if roam_repro == 'success':
            roam_repro_success += 1
        sim_repro = row[sim_repro_idx].strip().lower()
        if sim_repro == 'success':
            sim_repro_success += 1
        dist_repro = row[dist_repro_idx].strip().lower()
        if dist_repro == 'success':
            dist_repro_success += 1
    
    avg_roam_match = sum(roam_match_vals) / len(roam_match_vals) if roam_match_vals else 0
    avg_sim_match = sum(sim_match_vals) / len(sim_match_vals) if sim_match_vals else 0
    avg_dist_match = sum(dist_match_vals) / len(dist_match_vals) if dist_match_vals else 0
    
    roam_repro_rate = roam_repro_success / total if total > 0 else 0
    sim_repro_rate = sim_repro_success / total if total > 0 else 0
    dist_repro_rate = dist_repro_success / total if total > 0 else 0
    
    return {
        'Roam': {'match': avg_roam_match, 'repro': roam_repro_rate},
        'Roam-Sim': {'match': avg_sim_match, 'repro': sim_repro_rate},
        'Roam-Dist': {'match': avg_dist_match, 'repro': dist_repro_rate}
    }

def main():
    with open('/workspace/results.md', 'r', encoding='utf-8') as f:
        md = f.read()
    table = parse_markdown_table(md)
    if not table or len(table) < 3:
        print("Failed to parse table")
        sys.exit(1)
    results = compute_averages(table)
    with open('/workspace/repro.txt', 'w') as f:
        f.write("**Table 5: The Match Accuracy and Reproduction Rate for RQ5**\n\n")
        f.write("|           | Avg. Match Accuracy (%) | Reproduction Rate (%) |\n")
        f.write("| --------- | :---------------------: | :-------------------: |\n")
        for variant in ['Roam-Sim', 'Roam-Dist', 'Roam']:
            data = results[variant]
            match_pct = data['match'] * 100
            repro_pct = data['repro'] * 100
            f.write(f"| {variant}  |            {match_pct:.0f}           |           {repro_pct:.0f}          |\n")

if __name__ == '__main__':
    main()
PYEOF
python3 /workspace/compute_table5_final.py
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
