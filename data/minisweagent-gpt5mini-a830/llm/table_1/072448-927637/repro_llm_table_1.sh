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

# Section 2: Artifact download (idempotent: will overwrite existing files)
echo "Downloading artifact..."
curl -L --fail -o /workspace/GILT_Artifacts.zip "https://zenodo.org/records/10461385/files/GILT_Artifacts.zip?download=1" || { echo "Failed to download artifact"; exit 1; }
unzip -o /workspace/GILT_Artifacts.zip -d /workspace || { echo "Failed to unzip artifact"; exit 1; }

# Section 3: Reproduction commands - create and run an R script to reproduce Table 1
cat > /workspace/run_table1.R <<'Rscript'
suppressPackageStartupMessages({
  library(rsq)
  library(broom)
})

# helper to add significance stars
stars <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.01) return("***")
  if (p < 0.05) return("**")
  if (p < 0.1) return("*")
  return("")
}

fmt_num <- function(x) {
  if (is.na(x)) return("NA")
  sprintf("%.2f", x)
}

# load data
data_path <- "/workspace/GILT_Artifacts-main/study/study_data.csv"
if (!file.exists(data_path)) stop("Data file not found: ", data_path)
df <- read.csv(data_path, header=TRUE, stringsAsFactors=FALSE)

out_lines <- c()
out_lines <- c(out_lines, "**Reproduced Table 1 outputs**", "")

# function to run model for a given outcome and family/lm flag, plus optional subset
run_model <- function(outcome, family=NULL, subset_expr=NULL) {
  Q <- quantile(df[[outcome]], probs=c(.01,.99), na.rm=TRUE)
  eliminated <- df[ df[[outcome]] >= Q[1] & df[[outcome]] <= Q[2], ]
  if (!is.null(subset_expr)) eliminated <- eliminated[ subset_expr(eliminated), ]
  form <- as.formula(paste0(outcome, " ~ tool + experience + recruiting.years + AI_experience"))
  if (is.null(family)) {
    m <- lm(form, data=eliminated)
  } else {
    m <- glm(form, data=eliminated, family=family)
  }
  list(model=m, data=eliminated)
}

# run models exactly as in the notebook
time_res <- run_model("success_time_no_guess", family=NULL)
under_res <- run_model("understanding", family=quasipoisson())
progress_res <- run_model("progress_no_guess", family=quasipoisson())
progress_pro_res <- run_model("progress_no_guess", family=quasipoisson(), subset_expr=function(d) d$is_professional==1)
progress_stu_res <- run_model("progress_no_guess", family=quasipoisson(), subset_expr=function(d) d$is_professional==0)

models <- list(
  Progress = progress_res$model,
  Time = time_res$model,
  Underst = under_res$model,
  Progress_Pros = progress_pro_res$model,
  Progress_Students = progress_stu_res$model
)

# extract coefficients for the 5 variables in the desired order
vars_map <- c("(Intercept)"="Constant", "experience"="Domain experience", "recruiting.years"="Program. experience", "AI_experience"="AI tool familiarity", "tool"="Uses GILT")
row_names <- c("Constant","Domain experience","Program. experience","AI tool familiarity","Uses GILT")

# prepare table matrix
cells <- matrix("", nrow=length(row_names), ncol=length(models), dimnames=list(row_names, names(models)))

r2_vals <- numeric(length(models))
adj_r2_vals <- numeric(length(models))

for (j in seq_along(models)) {
  name <- names(models)[j]
  m <- models[[j]]
  sm <- summary(m)
  coefs <- as.data.frame(sm$coefficients)
  # ensure rownames exist
  for (i in seq_along(row_names)) {
    varname <- names(vars_map)[i]  # careful index flow; we'll map by names
  }
  # fill cells by checking coefficient rows
  for (rn in rownames(coefs)) {
    pretty <- vars_map[rn]
    if (is.null(pretty) || is.na(pretty)) next
    est <- coefs[rn, "Estimate"]
    se <- coefs[rn, "Std. Error"]
    # p-value may be in column "Pr(>|t|)" or "Pr(>|z|)"
    pcol <- intersect(c("Pr(>|t|)","Pr(>|z|)","Pr(>|t|)"), colnames(coefs))[1]
    pval <- if (!is.na(pcol)) coefs[rn, pcol] else NA
    cell <- paste0(fmt_num(est), stars(pval), " (", fmt_num(se), ")")
    # put into correct row
    if (!is.null(pretty)) {
      cells[pretty, j] <- cell
    }
  }
  # compute R^2 / adj R^2
  if (inherits(m, "lm")) {
    r2_vals[j] <- round(summary(m)$r.squared, 3)
    adj_r2_vals[j] <- round(summary(m)$adj.r.squared, 3)
  } else {
    # use rsq package for generalized models (as in notebook)
    r2v <- tryCatch(rsq(m), error=function(e) NA)
    adjv <- tryCatch(rsq(m, adj=TRUE), error=function(e) NA)
    r2_vals[j] <- ifelse(is.na(r2v), NA, round(as.numeric(r2v),3))
    adj_r2_vals[j] <- ifelse(is.na(adjv), NA, round(as.numeric(adjv),3))
  }
}

# Build markdown table header
header <- "|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |"
sep <- "| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |"

out_lines <- c(out_lines, header, sep)

for (i in seq_len(nrow(cells))) {
  row <- paste0("| ", rownames(cells)[i], strrep(" ", max(1,19 - nchar(rownames(cells)[i]))), " |")
  # append each column cell
  for (j in seq_len(ncol(cells))) {
    cell <- cells[i,j]
    if (cell == "") cell <- "NA"
    row <- paste0(row, " ", sprintf("%14s", cell), " |")
  }
  out_lines <- c(out_lines, row)
}

# R^2 rows
r2_line <- paste0("| *R*²                |", paste0(sprintf(" %13s |", format(r2_vals, nsmall=3)), collapse=""))
adj_line <- paste0("| Adj. *R*²           |", paste0(sprintf(" %13s |", format(adj_r2_vals, nsmall=3)), collapse=""))

out_lines <- c(out_lines, r2_line, adj_line, "")

# significance note
out_lines <- c(out_lines, "*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*", "")

# write to repro.txt
writeLines(out_lines, "/workspace/repro.txt")
cat("Wrote reproduction output to /workspace/repro.txt\n")
Rscript
# run the R script
Rscript /workspace/run_table1.R > /workspace/repro_run.log 2>&1 || { echo "R reproduction failed; see /workspace/repro_run.log"; cat /workspace/repro_run.log; exit 1; }

# show the produced reproduction output
echo "=== Reproduction output (short preview) ==="
sed -n '1,200p' /workspace/repro.txt || true

# Section 4: submission marker
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
