#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**

|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |
| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |
| Constant            |    ?.?? (?.??) | ???.?? (???.??) | -?.??** (?.??) |    -?.?? (?.??) |       ?.??** (?.??) |
| Domain experience   |   ?.??* (?.??) |   ??.?? (??.??) | ?.??*** (?.??) |     ?.?? (?.??) |         ?.?? (?.??) |
| Program. experience |   -?.?? (?.??) |  -??.?? (??.??) |    ?.?? (?.??) |     ?.?? (?.??) |       -?.??* (?.??) |
| AI tool familiarity |   -?.?? (?.??) |    ?.?? (??.??) |   -?.?? (?.??) |     ?.?? (?.??) |        -?.?? (?.??) |
| Uses GILT           | ?.??*** (?.??) |   -?.?? (??.??) |    ?.?? (?.??) |   ?.??** (?.??) |         ?.?? (?.??) |
| *R*²                |          ?.??? |           ?.??? |          ?.??? |           ?.??? |               ?.??? |
| Adj. *R*²           |          ?.??? |          -?.??? |          ?.??? |           ?.??? |               ?.??? |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10461385

# Section 3: Reproduction commands
docker pull jupyter/r-notebook
docker rm -f gilt_notebook || true
docker run -d --init --entrypoint bash --name gilt_notebook -v /workspace/GILT_Artifacts/GILT_Artifacts-main/study:/home/jovyan/work jupyter/r-notebook -c 'sleep infinity'

# Install system dependency for nloptr (needed by lme4 -> rsq) inside the container as root
docker exec -u root gilt_notebook bash -lc "apt-get update && apt-get install -y libnlopt-dev && apt-get clean"

# R script to run the regressions and emit Table 1 as markdown
cat > /workspace/gilt_table1_table.R <<'RSCRIPT'
options(scipen = 999)

df <- read.csv(file = "study_data.csv", header = TRUE)

if (!requireNamespace("rsq", quietly = TRUE)) {
  install.packages("rsq", repos = "https://cloud.r-project.org")
}
library(rsq)

cell <- function(est, se, p) {
  stars <- if (p < 0.01) {
    "***"
  } else if (p < 0.05) {
    "**"
  } else if (p < 0.1) {
    "*"
  } else {
    ""
  }
  sprintf("%.2f%s (%.2f)", round(est, 2), stars, round(se, 2))
}

# TIME model (linear regression)
Q <- quantile(df$success_time_no_guess, probs = c(0.01, 0.99), na.rm = FALSE)
elim_time <- subset(df, df$success_time_no_guess >= Q[1] & df$success_time_no_guess <= Q[2])
m_time <- lm(success_time_no_guess ~ tool + experience + recruiting.years + AI_experience, data = elim_time)
s_time <- summary(m_time)
cs_time <- coef(s_time)

# UNDERSTANDING model (quasi-Poisson)
Q <- quantile(df$understanding, probs = c(0.01, 0.99), na.rm = FALSE)
elim_under <- subset(df, df$understanding >= Q[1] & df$understanding <= Q[2])
m_under <- glm(understanding ~ tool + experience + recruiting.years + AI_experience,
               data = elim_under, family = quasipoisson)
cs_under <- coef(summary(m_under))
r2_under      <- as.numeric(rsq(m_under))
r2_under_adj  <- as.numeric(rsq(m_under, adj = TRUE))

# PROGRESS (ALL) model (quasi-Poisson)
Q <- quantile(df$progress_no_guess, probs = c(0.01, 0.99), na.rm = FALSE)
elim_prog <- subset(df, df$progress_no_guess >= Q[1] & df$progress_no_guess <= Q[2])
m_prog_all <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience,
                  data = elim_prog, family = quasipoisson)
cs_prog_all <- coef(summary(m_prog_all))
r2_prog_all      <- as.numeric(rsq(m_prog_all))
r2_prog_all_adj  <- as.numeric(rsq(m_prog_all, adj = TRUE))

# PROGRESS (PROFESSIONALS)
elim_prof <- elim_prog[elim_prog$is_professional == 1, ]
m_prog_prof <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience,
                   data = elim_prof, family = quasipoisson)
cs_prog_prof <- coef(summary(m_prog_prof))
r2_prog_prof      <- as.numeric(rsq(m_prog_prof))
r2_prog_prof_adj  <- as.numeric(rsq(m_prog_prof, adj = TRUE))

# PROGRESS (STUDENTS)
elim_stud <- elim_prog[elim_prog$is_professional == 0, ]
m_prog_stud <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience,
                   data = elim_stud, family = quasipoisson)
cs_prog_stud <- coef(summary(m_prog_stud))
r2_prog_stud      <- as.numeric(rsq(m_prog_stud))
r2_prog_stud_adj  <- as.numeric(rsq(m_prog_stud, adj = TRUE))

# Map dataset variables to paper labels:
# Domain experience   -> experience
# Program. experience -> recruiting.years
# AI tool familiarity -> AI_experience
# Uses GILT           -> tool

# Build coefficient cells
const_prog      <- cell(cs_prog_all["(Intercept)", "Estimate"],      cs_prog_all["(Intercept)", "Std. Error"],      cs_prog_all["(Intercept)", "Pr(>|t|)"])
const_time      <- cell(cs_time     ["(Intercept)", "Estimate"],      cs_time     ["(Intercept)", "Std. Error"],      cs_time     ["(Intercept)", "Pr(>|t|)"])
const_under     <- cell(cs_under    ["(Intercept)", "Estimate"],      cs_under    ["(Intercept)", "Std. Error"],      cs_under    ["(Intercept)", "Pr(>|t|)"])
const_prog_prof <- cell(cs_prog_prof["(Intercept)", "Estimate"],      cs_prog_prof["(Intercept)", "Std. Error"],      cs_prog_prof["(Intercept)", "Pr(>|t|)"])
const_prog_stud <- cell(cs_prog_stud["(Intercept)", "Estimate"],      cs_prog_stud["(Intercept)", "Std. Error"],      cs_prog_stud["(Intercept)", "Pr(>|t|)"])

dom_prog        <- cell(cs_prog_all["experience",  "Estimate"],      cs_prog_all["experience",  "Std. Error"],      cs_prog_all["experience",  "Pr(>|t|)"])
dom_time        <- cell(cs_time     ["experience",  "Estimate"],      cs_time     ["experience",  "Std. Error"],      cs_time     ["experience",  "Pr(>|t|)"])
dom_under       <- cell(cs_under    ["experience",  "Estimate"],      cs_under    ["experience",  "Std. Error"],      cs_under    ["experience",  "Pr(>|t|)"])
dom_prog_prof   <- cell(cs_prog_prof["experience",  "Estimate"],      cs_prog_prof["experience",  "Std. Error"],      cs_prog_prof["experience",  "Pr(>|t|)"])
dom_prog_stud   <- cell(cs_prog_stud["experience",  "Estimate"],      cs_prog_stud["experience",  "Std. Error"],      cs_prog_stud["experience",  "Pr(>|t|)"])

progexp_prog      <- cell(cs_prog_all["recruiting.years",  "Estimate"], cs_prog_all["recruiting.years",  "Std. Error"], cs_prog_all["recruiting.years",  "Pr(>|t|)"])
progexp_time      <- cell(cs_time     ["recruiting.years",  "Estimate"], cs_time     ["recruiting.years",  "Std. Error"], cs_time     ["recruiting.years",  "Pr(>|t|)"])
progexp_under     <- cell(cs_under    ["recruiting.years",  "Estimate"], cs_under    ["recruiting.years",  "Std. Error"], cs_under    ["recruiting.years",  "Pr(>|t|)"])
progexp_prog_prof <- cell(cs_prog_prof["recruiting.years", "Estimate"], cs_prog_prof["recruiting.years", "Std. Error"], cs_prog_prof["recruiting.years", "Pr(>|t|)"])
progexp_prog_stud <- cell(cs_prog_stud["recruiting.years", "Estimate"], cs_prog_stud["recruiting.years", "Std. Error"], cs_prog_stud["recruiting.years", "Pr(>|t|)"])

ai_prog        <- cell(cs_prog_all["AI_experience",  "Estimate"], cs_prog_all["AI_experience",  "Std. Error"], cs_prog_all["AI_experience",  "Pr(>|t|)"])
ai_time        <- cell(cs_time     ["AI_experience",  "Estimate"], cs_time     ["AI_experience",  "Std. Error"], cs_time     ["AI_experience",  "Pr(>|t|)"])
ai_under       <- cell(cs_under    ["AI_experience",  "Estimate"], cs_under    ["AI_experience",  "Std. Error"], cs_under    ["AI_experience",  "Pr(>|t|)"])
ai_prog_prof   <- cell(cs_prog_prof["AI_experience", "Estimate"], cs_prog_prof["AI_experience", "Std. Error"], cs_prog_prof["AI_experience", "Pr(>|t|)"])
ai_prog_stud   <- cell(cs_prog_stud["AI_experience", "Estimate"], cs_prog_stud["AI_experience", "Std. Error"], cs_prog_stud["AI_experience", "Pr(>|t|)"])

gilt_prog      <- cell(cs_prog_all["tool",  "Estimate"], cs_prog_all["tool",  "Std. Error"], cs_prog_all["tool",  "Pr(>|t|)"])
gilt_time      <- cell(cs_time     ["tool",  "Estimate"], cs_time     ["tool",  "Std. Error"], cs_time     ["tool",  "Pr(>|t|)"])
gilt_under     <- cell(cs_under    ["tool",  "Estimate"], cs_under    ["tool",  "Std. Error"], cs_under    ["tool",  "Pr(>|t|)"])
gilt_prog_prof <- cell(cs_prog_prof["tool", "Estimate"], cs_prog_prof["tool", "Std. Error"], cs_prog_prof["tool", "Pr(>|t|)"])
gilt_prog_stud <- cell(cs_prog_stud["tool", "Estimate"], cs_prog_stud["tool", "Std. Error"], cs_prog_stud["tool", "Pr(>|t|)"])

# R-squared values (lm and rsq for glm)
r2_time     <- sprintf("%.3f", round(s_time$r.squared, 3))
adj_time    <- sprintf("%.3f", round(s_time$adj.r.squared, 3))
r2_under_c  <- sprintf("%.3f", round(r2_under, 3))
adj_under_c <- sprintf("%.3f", round(r2_under_adj, 3))
r2_prog_c   <- sprintf("%.3f", round(r2_prog_all, 3))
adj_prog_c  <- sprintf("%.3f", round(r2_prog_all_adj, 3))
r2_prof_c   <- sprintf("%.3f", round(r2_prog_prof, 3))
adj_prof_c  <- sprintf("%.3f", round(r2_prog_prof_adj, 3))
r2_stud_c   <- sprintf("%.3f", round(r2_prog_stud, 3))
adj_stud_c  <- sprintf("%.3f", round(r2_prog_stud_adj, 3))

# Emit markdown table
cat("**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**\n\n")
cat("|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |\n")
cat("| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |\n")
cat("| Constant            | ", const_prog,      " | ", const_time,      " | ", const_under,     " | ", const_prog_prof, " | ", const_prog_stud, " |\n", sep = "")
cat("| Domain experience   | ", dom_prog,        " | ", dom_time,        " | ", dom_under,       " | ", dom_prog_prof,   " | ", dom_prog_stud,   " |\n", sep = "")
cat("| Program. experience | ", progexp_prog,    " | ", progexp_time,    " | ", progexp_under,   " | ", progexp_prog_prof," | ", progexp_prog_stud," |\n", sep = "")
cat("| AI tool familiarity | ", ai_prog,         " | ", ai_time,         " | ", ai_under,        " | ", ai_prog_prof,     " | ", ai_prog_stud,     " |\n", sep = "")
cat("| Uses GILT           | ", gilt_prog,       " | ", gilt_time,       " | ", gilt_under,      " | ", gilt_prog_prof,   " | ", gilt_prog_stud,   " |\n", sep = "")
cat("| *R*²                | ", r2_prog_c,       " | ", r2_time,         " | ", r2_under_c,      " | ", r2_prof_c,        " | ", r2_stud_c,        " |\n", sep = "")
cat("| Adj. *R*²           | ", adj_prog_c,      " | ", adj_time,        " | ", adj_under_c,     " | ", adj_prof_c,       " | ", adj_stud_c,       " |\n", sep = "")
cat("\n\n*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*\n")
RSCRIPT

# Copy R script into the container and run it; capture markdown to repro.txt
docker cp /workspace/gilt_table1_table.R gilt_notebook:/tmp/gilt_table1_table.R
docker exec gilt_notebook /bin/bash --noprofile --norc -c "cd /home/jovyan/work && Rscript /tmp/gilt_table1_table.R" > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
