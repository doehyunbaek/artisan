#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**

|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |
| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |
| Constant            |    0.41 (0.49) | 312.65 (185.33) | -1.81** (0.89) |    -0.38 (0.68) |       1.82** (0.83) |
| Domain experience   |   0.13* (0.07) |   23.14 (25.40) | 0.41*** (0.12) |     0.16 (0.09) |         0.04 (0.11) |
| Program. experience |   -0.10 (0.12) |  -23.67 (43.53) |    0.20 (0.22) |     0.01 (0.17) |       -0.37* (0.21) |
| AI tool familiarity |   -0.01 (0.07) |    7.70 (27.04) |   -0.09 (0.14) |     0.07 (0.11) |        -0.10 (0.10) |
| Uses GILT           | 0.47*** (0.16) |   -9.10 (57.26) |    0.29 (0.28) |   0.57** (0.22) |         0.29 (0.25) |
| *R*²                |          0.173 |           0.022 |          0.202 |           0.341 |               0.137 |
| Adj. *R*²           |          0.117 |          -0.046 |          0.148 |           0.243 |               0.010 |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L -o GILT_Artifacts.zip https://zenodo.org/api/records/10461385/files/GILT_Artifacts.zip/content
unzip -q -o GILT_Artifacts.zip
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/GILT_Artifacts-main/study
# Use R to rerun the regression models and capture key outputs used in Table 1
Rscript - <<'EORSCRIPT' > /workspace/repro_raw.txt
library(lme4)
library(lmerTest)
library(MuMIn)
library(lattice)
library(car)
library(gridExtra)
library(plyr)
library(rsq)
library(parameters)
library(tidyverse)
library(dplyr)
library(tidyr)
library(reshape2)

df <- read.csv(file="ase_data.csv", header=TRUE)

# Time model (2)
Q <- quantile(df$success_time_no_guess, probs=c(.01, .99), na.rm = FALSE)
eliminated<- subset(df, df$success_time_no_guess >= Q[1] & df$success_time_no_guess <= Q[2])
no_guess_time_model = lm(success_time_no_guess ~ tool + experience + recruiting.years + AI_experience, data = eliminated)
cat("TIME MODEL (2)\n")
print(summary(no_guess_time_model))

# Understanding model (3)
Q <- quantile(df$understanding, probs=c(.01, .99), na.rm = FALSE)
eliminated<- subset(df, df$understanding >= Q[1] & df$understanding <= Q[2])
understanding_model = glm(understanding ~ tool + experience + recruiting.years + AI_experience, data = eliminated, family=quasipoisson)
cat("\nUNDERSTANDING MODEL (3)\n")
print(summary(understanding_model))
cat("R2:", rsq(understanding_model), "AdjR2:", rsq(understanding_model, adj=TRUE), "\n")

# Progress model, all (1)
Q <- quantile(df$progress_no_guess, probs=c(.01, .99), na.rm = FALSE)
eliminated<- subset(df, df$progress_no_guess >= Q[1] & df$progress_no_guess <= Q[2])
progress_model_all = glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data = eliminated, family=quasipoisson)
cat("\nPROGRESS MODEL ALL (1)\n")
print(summary(progress_model_all))
cat("R2:", rsq(progress_model_all), "AdjR2:", rsq(progress_model_all, adj=TRUE), "\n")

# Progress model, professionals
progress_model_pro = glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data = eliminated[eliminated$is_professional==1,], family=quasipoisson)
cat("\nPROGRESS MODEL PROFESSIONALS\n")
print(summary(progress_model_pro))
cat("R2:", rsq(progress_model_pro), "AdjR2:", rsq(progress_model_pro, adj=TRUE), "\n")

# Progress model, students
progress_model_stu = glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data = eliminated[eliminated$is_professional==0,], family=quasipoisson)
cat("\nPROGRESS MODEL STUDENTS\n")
print(summary(progress_model_stu))
cat("R2:", rsq(progress_model_stu), "AdjR2:", rsq(progress_model_stu, adj=TRUE), "\n")
EORSCRIPT

# Extract a concise table-ish summary to /workspace/repro.txt
cd /workspace
python - <<'EOPY'
import re
from pathlib import Path
text = Path('repro_raw.txt').read_text()

sections = {
    'PROGRESS (1)': r'PROGRESS MODEL ALL \(1\)(.*?)(?=PROGRESS MODEL PROFESSIONALS|$)',
    'TIME (2)': r'TIME MODEL \(2\)(.*?)(?=UNDERSTANDING MODEL \(3\)|$)',
    'UNDERSTANDING (3)': r'UNDERSTANDING MODEL \(3\)(.*?)(?=PROGRESS MODEL ALL \(1\)|$)',
    'PROGRESS (PROS)': r'PROGRESS MODEL PROFESSIONALS(.*?)(?=PROGRESS MODEL STUDENTS|$)',
    'PROGRESS (STUDENTS)': r'PROGRESS MODEL STUDENTS(.*)$',
}

out_lines = []
for name, pattern in sections.items():
    m = re.search(pattern, text, re.S)
    if not m:
        continue
    block = m.group(1)
    out_lines.append(f"===== {name} =====")
    for line in block.splitlines():
        if any(key in line for key in ["(Intercept)", "tool ", "experience ", "recruiting.years", "AI_experience", "Multiple R-squared", "Adjusted R-squared", "R2:"]):
            out_lines.append(line.rstrip())
    out_lines.append("")

Path('repro.txt').write_text("\n".join(out_lines))
EOPY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
