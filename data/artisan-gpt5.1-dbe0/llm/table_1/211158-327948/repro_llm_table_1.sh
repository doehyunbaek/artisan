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
# Section 3: Reproduction commands (populate from reviewed steps)
docker pull jupyter/r-notebook
docker run -d --init --name notebook -v /workspace/GILT_Artifacts/GILT_Artifacts-main/study:/home/jovyan/work --entrypoint bash jupyter/r-notebook -c 'sleep infinity'
docker exec notebook /bin/bash --noprofile --norc -c "conda install -y -c conda-forge r-rsq"
cat > /workspace/GILT_Artifacts/GILT_Artifacts-main/study/repro_table1.R <<'EOR'
#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(rsq))

df <- read.csv("study_data.csv", header = TRUE)

## Time model (lm) with 1–99% trimming
Q_time <- quantile(df$success_time_no_guess, probs = c(.01, .99), na.rm = FALSE)
elim_time <- subset(df, df$success_time_no_guess >= Q_time[1] & df$success_time_no_guess <= Q_time[2])
time_model <- lm(
  success_time_no_guess ~ tool + experience + recruiting.years + AI_experience,
  data = elim_time
)
time_sm <- summary(time_model)

## Understanding model (glm) — use global 'eliminated' as in notebook
Q <- quantile(df$understanding, probs = c(.01, .99), na.rm = FALSE)
eliminated <- subset(df, df$understanding >= Q[1] & df$understanding <= Q[2])
under_model <- glm(
  understanding ~ tool + experience + recruiting.years + AI_experience,
  data = eliminated,
  family = quasipoisson
)
under_sm <- summary(under_model)

## Progress model (all participants) — reuse global 'eliminated'
Q <- quantile(df$progress_no_guess, probs = c(.01, .99), na.rm = FALSE)
eliminated <- subset(df, df$progress_no_guess >= Q[1] & df$progress_no_guess <= Q[2])
prog_model <- glm(
  progress_no_guess ~ tool + experience + recruiting.years + AI_experience,
  data = eliminated,
  family = quasipoisson
)
prog_sm <- summary(prog_model)

## Progress (professionals)
prog_prof_model <- glm(
  progress_no_guess ~ tool + experience + recruiting.years + AI_experience,
  data = eliminated[eliminated$is_professional == TRUE, ],
  family = quasipoisson
)
prog_prof_sm <- summary(prog_prof_model)

## Progress (students)
prog_stud_model <- glm(
  progress_no_guess ~ tool + experience + recruiting.years + AI_experience,
  data = eliminated[eliminated$is_professional == FALSE, ],
  family = quasipoisson
)
prog_stud_sm <- summary(prog_stud_model)

## Coefficient formatter
coef_row <- function(sm, term) {
  coefs <- sm$coefficients
  if (!term %in% rownames(coefs)) return("NA (NA)")
  est <- coefs[term, "Estimate"]
  se  <- coefs[term, "Std. Error"]
  p   <- coefs[term, ncol(coefs)]
  stars <- if (is.na(p)) {
    ""
  } else if (p < 0.01) {
    "***"
  } else if (p < 0.05) {
    "**"
  } else if (p < 0.1) {
    "*"
  } else {
    ""
  }
  sprintf("%.2f%s (%.2f)", est, stars, se)
}

## R² helpers
r2_lm  <- function(sm)    c(r2 = sm$r.squared,        adj = sm$adj.r.squared)
r2_glm <- function(model) c(r2 = as.numeric(rsq(model)),
                            adj = as.numeric(rsq(model, adj = TRUE)))

terms <- c("(Intercept)", "experience", "recruiting.years", "AI_experience", "tool")

prog_coefs  <- sapply(terms, coef_row, sm = prog_sm)
time_coefs  <- sapply(terms, coef_row, sm = time_sm)
under_coefs <- sapply(terms, coef_row, sm = under_sm)
prof_coefs  <- sapply(terms, coef_row, sm = prog_prof_sm)
stud_coefs  <- sapply(terms, coef_row, sm = prog_stud_sm)

prog_r2  <- r2_glm(prog_model)
time_r2  <- r2_lm(time_sm)
under_r2 <- r2_glm(under_model)
prof_r2  <- r2_glm(prog_prof_model)
stud_r2  <- r2_glm(prog_stud_model)

fmt_r2 <- function(x) sprintf("%.3f", x)

cat("**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**\n\n")
cat("|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |\n")
cat("| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |\n")

row_out <- function(label, idx) {
  cat(sprintf("| %-19s | %14s | %15s | %14s | %14s | %18s |\n",
              label,
              prog_coefs[idx],
              time_coefs[idx],
              under_coefs[idx],
              prof_coefs[idx],
              stud_coefs[idx]))
}

row_out("Constant", "(Intercept)")
row_out("Domain experience", "experience")
row_out("Program. experience", "recruiting.years")
row_out("AI tool familiarity", "AI_experience")
row_out("Uses GILT", "tool")

cat(sprintf("| *R*²                | %13s | %14s | %11s | %11s | %15s |\n",
            fmt_r2(prog_r2["r2"]),
            fmt_r2(time_r2["r2"]),
            fmt_r2(under_r2["r2"]),
            fmt_r2(prof_r2["r2"]),
            fmt_r2(stud_r2["r2"])))
cat(sprintf("| Adj. *R*²           | %13s | %14s | %11s | %11s | %15s |\n",
            fmt_r2(prog_r2["adj"]),
            fmt_r2(time_r2["adj"]),
            fmt_r2(under_r2["adj"]),
            fmt_r2(prof_r2["adj"]),
            fmt_r2(stud_r2["adj"])))
cat("\n\n*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*\n")
EOR
docker exec notebook /bin/bash --noprofile --norc -c "cd /home/jovyan/work && Rscript repro_table1.R" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
