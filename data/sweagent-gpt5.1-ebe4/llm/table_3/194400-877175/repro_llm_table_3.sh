#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**

|                     |     Prompt (1) |  Followup (2) |        All (3) |
| ------------------- | -------------: | ------------: | -------------: |
| Constant            | 1.39*** (0.31) |  -0.82 (0.69) | 2.43*** (0.27) |
| AI tool familiarity |  0.19** (0.07) | 0.38** (0.15) |    0.11 (0.06) |
| Information Comprh. |   -0.04 (0.15) |   0.44 (0.30) |   -0.04 (0.13) |
| Learning Process    |    0.19 (0.14) | 0.60** (0.29) |   -0.12 (0.13) |
| *R*²                |          0.263 |         0.283 |          0.165 |
| Adj. *R*²           |          0.184 |         0.206 |          0.075 |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE
# Section 2: Artifact download
cd /workspace
# Download artifact from Zenodo
curl -L 'https://zenodo.org/records/10461385/files/GILT_Artifacts.zip' -o GILT_Artifacts.zip
unzip -o GILT_Artifacts.zip

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/GILT_Artifacts-main/study
# Convert the R notebook to an R script and execute the relevant analysis to regenerate Table 3
# We assume Rscript and Jupyter are available in the environment.
# First, convert the notebook to a markdown file for easier grepping (no execution needed here).
# Then, run R to reproduce the analysis and capture the regression table output.

# Extract R code cells from the notebook using jupyter nbconvert, if available.
if command -v jupyter >/dev/null 2>&1; then
  jupyter nbconvert --to script analysis.ipynb --output analysis
fi

# Run the R-based analysis directly via Rscript if the script exists; otherwise, fall back to using the notebook via nbconvert --execute.
if [ -f analysis.r ] || [ -f analysis.R ]; then
  Rscript analysis.r  > /workspace/repro_raw.txt 2>&1 || Rscript analysis.R > /workspace/repro_raw.txt 2>&1
else
  if command -v jupyter >/dev/null 2>&1; then
    jupyter nbconvert --to markdown --execute analysis.ipynb --output analysis_executed
    # Save full executed notebook output
    cp analysis_executed.md /workspace/repro_raw.txt
  else
    echo "jupyter not available; cannot automatically execute the notebook" > /workspace/repro_raw.txt
  fi
fi

# Filter the regression output related to Table 3 into /workspace/repro.txt
cd /workspace
if [ -f repro_raw.txt ]; then
  # Grep for key variable names to capture the regression table
  grep -i -E 'Prompt \(1\)|Followup \(2\)|All \(3\)|AI tool familiarity|Information Comprh|Learning Process|R\^2|Adj' repro_raw.txt > repro.txt || cp repro_raw.txt repro.txt
else
  echo "repro_raw.txt not found" > repro.txt
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Simply cat the reproduction output; any additional formatting can be added if needed.
cat /workspace/repro.txt
echo '</artisan_submit>'
