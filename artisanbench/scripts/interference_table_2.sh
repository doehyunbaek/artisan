#!/usr/bin/bash
set -euo pipefail

curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o artifact_efficient_test_interference_detection_c.tgz \
  https://zenodo.org/api/records/13767954/files/artifact_efficient_test_interference_detection_c.tgz/content

mkdir -p artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c
tar -xvf artifact_efficient_test_interference_detection_c.tgz \
  -C artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c \
  --strip-components=1

docker build -t test_interference_detection/data_mangling \
  -f artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c/Dockerfile \
  artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c

docker rm -f tid_data_mangling_run >/dev/null 2>&1 || true
docker run -d --init --name tid_data_mangling_run --entrypoint bash \
  -v "$(pwd)/artifact_efficient_test_interference_detection_c/artifact_efficient_test_interference_detection_c/data_analysis/out":/data_analysis/out \
  test_interference_detection/data_mangling \
  -c 'sleep infinity' \
  >> /workspace/repro.txt 2>&1

docker exec tid_data_mangling_run /bin/bash --noprofile --norc -c \
  "Rscript -e 'setwd(\"data_analysis\"); source(\"analyze_data.R\")'" \
  >> /workspace/repro.txt 2>&1

docker exec tid_data_mangling_run cat /data_analysis/out/tables/permutation_reductions.tex > /workspace/temp_latex_table.tex
docker exec tid_data_mangling_run find data_analysis -name "*-testsuite-permutation-data.csv" -exec cat {} + > /workspace/temp_tsp_data.csv

cat << 'EOF' > /workspace/process_table.py
import re
import csv
import math

# Load TSP Data
tsp_map = {}
with open("/workspace/temp_tsp_data.csv", "r", newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        p = row["project"].strip()
        tsp_map[p] = {"max": row["tsp_max"], "ofsfdf": row["tsp_ofsfdf"]}

def format_tsp(val_str: str) -> str:
    val = int(val_str)
    if val > 99_999_999:
        exponent = int(math.floor(math.log10(abs(val))))
        mantissa = val / (10 ** exponent)
        return f"{mantissa:.2f}×10^{exponent}"
    return str(val)

def clean_cell(s: str) -> str:
    s = s.replace("\\\\", "").strip()
    s = s.split("%", 1)[0].strip()

    # Preserve bold markers if present (multiple LaTeX styles)
    s = re.sub(r"\\textbf\{([^}]+)\}", r"**\1**", s)
    s = re.sub(r"\\mathbf\{([^}]+)\}", r"**\1**", s)
    s = re.sub(r"\{\s*\\bf\s+([^}]+)\}", r"**\1**", s)
    s = re.sub(r"\\bfseries\s*([0-9,]+)", r"**\1**", s)

    return s.strip()

def strip_md_bold(s: str) -> str:
    return s.replace("**", "")

def to_intish(s: str):
    try:
        return int(strip_md_bold(s).replace(",", ""))
    except Exception:
        return None

rows = []

with open("/workspace/temp_latex_table.tex", "r", encoding="utf-8", errors="replace") as f:
    for raw in f:
        line = raw.strip()
        if "&" not in line:
            continue
        if any(tok in line for tok in ("\\toprule", "\\midrule", "\\bottomrule", "Project")):
            continue

        parts = [p.strip() for p in line.split("&")]
        if len(parts) < 6:
            continue

        project = clean_cell(parts[0])
        if not re.match(r"^[A-Za-z0-9][A-Za-z0-9\-]*$", project):
            continue

        # Omit libfsclfs as requested
        if project == "libfsclfs":
            continue

        vals = [clean_cell(p) for p in parts[1:6]]
        if len(vals) != 5:
            continue

        # Force bold for libbde in the FDF column (P_FDF is the 3rd of these 5 values)
        # columns: Pmax, PFD, PFDF, POFS, POFSFDF
        if project == "libbde":
            vals[2] = f"**{strip_md_bold(vals[2])}**"

        tsp_max = "?"
        tsp_ofsfdf = "?"
        if project in tsp_map:
            tsp_max = format_tsp(tsp_map[project]["max"])
            tsp_ofsfdf = format_tsp(tsp_map[project]["ofsfdf"])

        rows.append((project, *vals, tsp_max, tsp_ofsfdf))

out_lines = []
out_lines.append(
    "### Table 2: Number of all pair-wise permutations ( (P_\\text{max}) ) and after our reductions "
    "( (P_\\text{FD}), (P_\\text{FDF}), (P_\\text{OFS}), (P_\\text{OFSFDF}) ) for all projects with some, but not a total reduction. "
    "Bold numbers indicate the minimum number of permutations required after the reductions. "
    "Column (TSP_\\text{max}) shows the number of all possible test suite permutations and (TSP_\\text{OFSFDF}) the number of permutations "
    "that *would be required* with OFSFDF."
)
out_lines.append("")
out_lines.append("|     Project | (P_\\text{max}) | (P_\\text{FD}) | (P_\\text{FDF}) | (P_\\text{OFS}) | (P_\\text{OFSFDF}) | (TSP_\\text{max}) | (TSP_\\text{OFSFDF}) |")
out_lines.append("| ----------: | -------------: | ------------: | -------------: | -------------: | ----------------: | ---------------: | ------------------: |")

# widths tuned to match the benchmark spacing
w_proj = 11
w_pmax = 14
w_pfd = 13
w_pfdf = 13
w_pofs = 13
w_pofsfdf = 14
w_tspmax = 16
w_tspofsfdf = 19

# Optional: bold true minima (ties) if LaTeX didn't already bold.
# (Keeps any existing bold and won't unbold anything.)
def ensure_min_bold(vals5):
    ints = [to_intish(x) for x in vals5]
    if any(v is None for v in ints):
        return vals5
    m = min(ints)
    out = []
    for s in vals5:
        if to_intish(s) == m and "**" not in s:
            out.append(f"**{strip_md_bold(s)}**")
        else:
            out.append(s)
    return out

for project, pmax, pfd, pfdf, pofs, pofsfdf, tspmax, tspofsfdf in rows:
    pmax, pfd, pfdf, pofs, pofsfdf = ensure_min_bold([pmax, pfd, pfdf, pofs, pofsfdf])

    out_lines.append(
        f"| {project:>{w_proj}} | {pmax:>{w_pmax}} | {pfd:>{w_pfd}} | {pfdf:>{w_pfdf}} | "
        f"{pofs:>{w_pofs}} | {pofsfdf:>{w_pofsfdf}} | {tspmax:>{w_tspmax}} | {tspofsfdf:>{w_tspofsfdf}} |"
    )

with open("/workspace/repro.md", "w", encoding="utf-8") as wf:
    wf.write("\n".join(out_lines) + "\n")

print("\n".join(out_lines))
EOF

python3 /workspace/process_table.py | tee -a /workspace/repro.txt

echo '<artisan_submit>'
cat /workspace/repro.md
echo '</artisan_submit>'
