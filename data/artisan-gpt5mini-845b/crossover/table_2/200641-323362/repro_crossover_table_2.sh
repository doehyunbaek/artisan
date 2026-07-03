#!/usr/bin/bash
set -euo pipefail

# Create local expected.md for the formatter to use
cat > expected.md <<'EOTABLE'
**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**

| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |
| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |
| Ant     |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| BCEL    |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Closure |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Maven   |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Nashorn |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Rhino   |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
| Tomcat  |     ?.??? |     ?.??? |        ?.??? |        ?.??? |        ?.??? |        ?.??? |
EOTABLE

# Download artifact to ensure heritability.csv is present in this environment
artisan get https://figshare.com/articles/code/_b_Artifact_for_Crossover_in_Parametric_Fuzzing_b_/23688879

# Locate heritability.csv
CSV=""
for c in "heritability.csv" "zeugma-main/heritability.csv" "zeugma-main/zeugma-main/heritability.csv" "/workspace/heritability.csv"; do
  if [ -f "$c" ]; then
    CSV="$c"
    break
  fi
done

if [ -z "$CSV" ]; then
  echo "heritability.csv not found" > repro.txt
else
  python3 - <<'PY'
import csv, statistics, os, sys

# Expected subject labels (as in the paper/table)
expected_subjects = ["Ant","BCEL","Closure","Maven","Nashorn","Rhino","Tomcat"]
# Mapping from lowercase CSV subject to expected label
map_lower_to_expected = {
    "ant": "Ant",
    "bcel": "BCEL",
    "bcel?": "BCEL",
    "closure": "Closure",
    "maven": "Maven",
    "nashorn": "Nashorn",
    "rhino": "Rhino",
    "tomcat": "Tomcat"
}

# Find CSV path from candidates (same order as shell)
candidates = ["heritability.csv", "zeugma-main/heritability.csv", "zeugma-main/zeugma-main/heritability.csv", "/workspace/heritability.csv"]
csv_path = None
for p in candidates:
    if os.path.exists(p):
        csv_path = p
        break
if not csv_path:
    sys.exit("heritability.csv not found")

data = {}
with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        subj = row.get("subject","").strip()
        if not subj:
            continue
        subj_key = subj.lower()
        mapped = map_lower_to_expected.get(subj_key, None)
        if mapped is None:
            # Try to match by substring (robust)
            for k,v in map_lower_to_expected.items():
                if k in subj_key:
                    mapped = v
                    break
        if mapped is None:
            continue
        op = row.get("crossover_operator","").strip()
        if not op:
            continue
        try:
            ir = float(row.get("inheritance_rate","nan"))
        except:
            continue
        hy = str(row.get("hybrid","")).strip().lower() == "true"
        data.setdefault((mapped, op), []).append((ir, hy))

# Compute metrics and write repro.txt
out_lines = []
out_lines.append("**Table 2: Heritability Metrics. For each crossover operator, we report the proportion of samples that were hybrids (HY) and the median inheritance rate (IR) on each subject. The largest value for each metric on each subject is highlighted in blue. Values that differ significantly from that of linked crossover are colored red.**\\n")
out_lines.append("\\n")
out_lines.append("| Subject | Linked HY | Linked IR | One Point HY | One Point IR | Two Point HY | Two Point IR |\\n")
out_lines.append("| ------- | --------: | --------: | -----------: | -----------: | -----------: | -----------: |\\n")
for s in expected_subjects:
    vals = []
    for op in ["Linked","One Point","Two Point"]:
        recs = data.get((s,op), [])
        if recs:
            irs = [r[0] for r in recs]
            hys = [r[1] for r in recs]
            hyprop = sum(hys)/len(hys)
            med = statistics.median(irs)
            vals.append(f"{hyprop:.3f}")
            vals.append(f"{med:.3f}")
        else:
            vals.append("?.???")
            vals.append("?.???")
    out_lines.append(f"| {s:<6} | {vals[0]:>7} | {vals[1]:>7} | {vals[2]:>11} | {vals[3]:>11} | {vals[4]:>11} | {vals[5]:>11} |\\n")

with open("repro.txt","w") as f:
    f.writelines(out_lines)
PY
fi

# Emit submission block and run artisan format on local expected.md and repro.txt
echo '<artisan_submit>'
artisan format --expected expected.md --repro repro.txt
echo '</artisan_submit>'
