#!/usr/bin/bash
# Repro script that preserves existing /workspace/expected.md and produces the reproduction output.
# Do not overwrite expected.md.

# Ensure the artifact is present
artisan get https://zenodo.org/records/10461385 || true

# Make sure the notebook can find the data file name it expects
if [ -f "GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv" ]; then
  cp -n GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv ase_data.csv || true
fi

# Locate notebook
NB_PATH=$(find . -path "*/study/analysis.ipynb" | head -n1)
if [ -z "$NB_PATH" ]; then
  echo "analysis.ipynb not found" >&2
  exit 1
fi

# Extract only code cells related to the Table 1 models and run them
python3 - <<PY
import json, re, os, sys
nb = json.load(open("$NB_PATH", 'r', encoding='utf-8'))
pattern = re.compile(r'progress_no_guess|success_time_no_guess|understanding|progress_model|no_guess_time_model|understanding_model', re.I)
cells = []
for cell in nb.get('cells', []):
    if cell.get('cell_type') == 'code':
        src = ''.join(cell.get('source', []))
        if pattern.search(src):
            cells.append(src)
out = '/tmp/table1_models.R'
with open(out, 'w', encoding='utf-8') as f:
    f.write('options(error=traceback)\\n')
    f.write('if (file.exists("ase_data.csv")) { df <- read.csv("ase_data.csv", stringsAsFactors=FALSE) } else if (file.exists("GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv")) { df <- read.csv("GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv", stringsAsFactors=FALSE) } else { stop("study data not found") }\\n\\n')
    for i, c in enumerate(cells):
        f.write("# ---- extracted cell %d ----\\n" % (i+1))
        f.write(c + "\\n\\n")
    f.write('\\n# Print summaries for key models if present\\n')
    f.write('for (n in c("no_guess_time_model","success_time_no_guess","success_time_no_guess_model","understanding_model","progress_model")) { if (exists(n)) { cat("===== SUMMARY:", n, "\\n"); try(print(summary(get(n))), silent=TRUE) } }\\n')
print(out)
PY

# Run the R script and capture output
Rscript /tmp/table1_models.R > /workspace/repro.txt 2>&1 || true

# Submission block with formatted table (do NOT overwrite expected.md)
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || true
echo '</artisan_submit>'

# Final required output
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
