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

# Section 2: Artifact download (if not present)
if [ ! -f /workspace/gilt_artifacts/GILT_Artifacts-main/study/study_data.csv ]; then
  echo "Downloading artifact..."
  curl -L -o /workspace/GILT_Artifacts.zip 'https://zenodo.org/records/10461385/files/GILT_Artifacts.zip'
  unzip -o /workspace/GILT_Artifacts.zip -d /workspace/gilt_artifacts
fi

# Section 3: Reproduction commands (R script)
cat > /tmp/run_table3.R <<'R_SCRIPT'
# Read data
df <- read.csv("/workspace/gilt_artifacts/GILT_Artifacts-main/study/study_data.csv", stringsAsFactors=FALSE)

# Ensure numeric types
df$AI_experience <- as.numeric(df$AI_experience)
df$info_style <- as.numeric(df$info_style)
df$learning_style <- as.numeric(df$learning_style)
df$tool <- as.numeric(df$tool)

# Subset to tool == 1 as in the notebook
sub <- df[df$tool == 1,]
n <- nrow(sub)

# Fit function returning coefficients, R2 and adjusted R2 (based on deviance)
fit_and_stats <- function(formula_str) {
  m <- glm(as.formula(formula_str), data=sub, family=quasipoisson)
  s <- summary(m)
  coefs <- s$coefficients
  # pseudo R2 based on deviance
  R2 <- if (!is.null(m$null.deviance) && m$null.deviance > 0) 1 - (m$deviance / m$null.deviance) else NA
  p <- length(coef(m))
  adjR2 <- if (!is.na(R2)) 1 - (1 - R2) * (n - 1) / (n - p) else NA
  list(coef = coefs, R2 = R2, adjR2 = adjR2, model = m)
}

m1 <- fit_and_stats("query_total ~ AI_experience + info_style + learning_style")
m2 <- fit_and_stats("Query_followup ~ AI_experience + info_style + learning_style")
m3 <- fit_and_stats("usage_total ~ AI_experience + info_style + learning_style")

# Helper to format coefficient with standard error
fmt <- function(coefs, name) {
  if (!(name %in% rownames(coefs))) return("NA (NA)")
  est <- coefs[name, "Estimate"]
  se  <- coefs[name, "Std. Error"]
  sprintf("%.2f (%.2f)", est, se)
}

# Write results to repro.txt in markdown table form
sink("/workspace/repro.txt")
cat("Reproduction results for Table 3 (models fit with quasipoisson on subset tool==1)\n\n")
cat("|                     |     Prompt (1) |  Followup (2) |        All (3) |\n")
cat("| ------------------- | -------------: | ------------: | -------------: |\n")
cat(sprintf("| Constant            | %15s | %12s | %13s |\n",
            fmt(m1$coef, "(Intercept)"), fmt(m2$coef, "(Intercept)"), fmt(m3$coef, "(Intercept)")))
cat(sprintf("| AI tool familiarity | %15s | %12s | %13s |\n",
            fmt(m1$coef, "AI_experience"), fmt(m2$coef, "AI_experience"), fmt(m3$coef, "AI_experience")))
cat(sprintf("| Information Comprh. | %15s | %12s | %13s |\n",
            fmt(m1$coef, "info_style"), fmt(m2$coef, "info_style"), fmt(m3$coef, "info_style")))
cat(sprintf("| Learning Process    | %15s | %12s | %13s |\n",
            fmt(m1$coef, "learning_style"), fmt(m2$coef, "learning_style"), fmt(m3$coef, "learning_style")))
cat(sprintf("| *R*²                | %15.3f | %12.3f | %13.3f |\n",
            ifelse(is.na(m1$R2), NaN, m1$R2), ifelse(is.na(m2$R2), NaN, m2$R2), ifelse(is.na(m3$R2), NaN, m3$R2)))
cat(sprintf("| Adj. *R*²           | %15.3f | %12.3f | %13.3f |\n",
            ifelse(is.na(m1$adjR2), NaN, m1$adjR2), ifelse(is.na(m2$adjR2), NaN, m2$adjR2), ifelse(is.na(m3$adjR2), NaN, m3$adjR2)))
sink()
R_SCRIPT

# Run the R script to produce /workspace/repro.txt
Rscript /tmp/run_table3.R

# Section 4: Output and completion
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
