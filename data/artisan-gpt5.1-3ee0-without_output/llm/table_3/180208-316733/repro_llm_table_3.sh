#!/usr/bin/bash
set -e

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**

|                     |     Prompt (1) |  Followup (2) |        All (3) |
| ------------------- | -------------: | ------------: | -------------: |
| Constant            | ?.??*** (?.??) |  -?.?? (?.??) | ?.??*** (?.??) |
| AI tool familiarity |  ?.??** (?.??) | ?.??** (?.??) |    ?.?? (?.??) |
| Information Comprh. |   -?.?? (?.??) |   ?.?? (?.??) |   -?.?? (?.??) |
| Learning Process    |    ?.?? (?.??) | ?.??** (?.??) |   -?.?? (?.??) |
| *R*²                |          ?.??? |         ?.??? |          ?.??? |
| Adj. *R*²           |          ?.??? |         ?.??? |          ?.??? |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/10461385

# Section 3: Reproduction commands – run GLMs in R via Docker and build the table
ART_ROOT="/workspace/GILT_Artifacts/GILT_Artifacts-main"
STUDY_DIR="${ART_ROOT}/study"

# Pull the official R notebook image
docker pull jupyter/r-notebook

# Ensure a clean container
docker rm -f gilt_r_notebook 2>/dev/null || true

# Start a background container with the study directory mounted
docker run -d --init --entrypoint bash \
  --name gilt_r_notebook \
  -v "${STUDY_DIR}":/home/jovyan/work \
  jupyter/r-notebook -c 'sleep infinity'

# Create an R script inside the mounted study directory that computes Table 3
cat > "${STUDY_DIR}/run_table3.R" <<'RSCRIPT'
df <- read.csv("study_data.csv", header = TRUE)
df_tool <- subset(df, tool == 1)

m1 <- glm(query_total ~ AI_experience + info_style + learning_style,
          data = df_tool, family = quasipoisson)
m2 <- glm(Query_followup ~ AI_experience + info_style + learning_style,
          data = df_tool, family = quasipoisson)
m3 <- glm(usage_total ~ AI_experience + info_style + learning_style,
          data = df_tool, family = quasipoisson)

if (!requireNamespace("rsq", quietly = TRUE)) {
  install.packages("rsq", repos = "https://cloud.r-project.org")
}
library(rsq)

r2_1  <- rsq(m1); r2a_1 <- rsq(m1, adj = TRUE)
r2_2  <- rsq(m2); r2a_2 <- rsq(m2, adj = TRUE)
r2_3  <- rsq(m3); r2a_3 <- rsq(m3, adj = TRUE)

fmt_coef <- function(est, se, p) {
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

s1 <- summary(m1)$coefficients
s2 <- summary(m2)$coefficients
s3 <- summary(m3)$coefficients

prompt_const <- fmt_coef(s1["(Intercept)", "Estimate"], s1["(Intercept)", "Std. Error"], s1["(Intercept)", "Pr(>|t|)"])
prompt_ai    <- fmt_coef(s1["AI_experience", "Estimate"], s1["AI_experience", "Std. Error"], s1["AI_experience", "Pr(>|t|)"])
prompt_info  <- fmt_coef(s1["info_style", "Estimate"], s1["info_style", "Std. Error"], s1["info_style", "Pr(>|t|)"])
prompt_learn <- fmt_coef(s1["learning_style", "Estimate"], s1["learning_style", "Std. Error"], s1["learning_style", "Pr(>|t|)"])

follow_const <- fmt_coef(s2["(Intercept)", "Estimate"], s2["(Intercept)", "Std. Error"], s2["(Intercept)", "Pr(>|t|)"])
follow_ai    <- fmt_coef(s2["AI_experience", "Estimate"], s2["AI_experience", "Std. Error"], s2["AI_experience", "Pr(>|t|)"])
follow_info  <- fmt_coef(s2["info_style", "Estimate"], s2["info_style", "Std. Error"], s2["info_style", "Pr(>|t|)"])
follow_learn <- fmt_coef(s2["learning_style", "Estimate"], s2["learning_style", "Std. Error"], s2["learning_style", "Pr(>|t|)"])

all_const <- fmt_coef(s3["(Intercept)", "Estimate"], s3["(Intercept)", "Std. Error"], s3["(Intercept)", "Pr(>|t|)"])
all_ai    <- fmt_coef(s3["AI_experience", "Estimate"], s3["AI_experience", "Std. Error"], s3["AI_experience", "Pr(>|t|)"])
all_info  <- fmt_coef(s3["info_style", "Estimate"], s3["info_style", "Std. Error"], s3["info_style", "Pr(>|t|)"])
all_learn <- fmt_coef(s3["learning_style", "Estimate"], s3["learning_style", "Std. Error"], s3["learning_style", "Pr(>|t|)"])

line_r2  <- sprintf("| *R*²                |          %.3f |         %.3f |          %.3f |",
                    r2_1, r2_2, r2_3)
line_r2a <- sprintf("| Adj. *R*²           |          %.3f |         %.3f |          %.3f |",
                    r2a_1, r2a_2, r2a_3)

lines <- c(
"**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**",
"",
"|                     |     Prompt (1) |  Followup (2) |        All (3) |",
"| ------------------- | -------------: | ------------: | -------------: |",
sprintf("| Constant            | %s | %s | %s |", prompt_const, follow_const, all_const),
sprintf("| AI tool familiarity | %s | %s | %s |", prompt_ai,    follow_ai,    all_ai),
sprintf("| Information Comprh. | %s | %s | %s |", prompt_info,  follow_info,  all_info),
sprintf("| Learning Process    | %s | %s | %s |", prompt_learn, follow_learn, all_learn),
line_r2,
line_r2a,
"",
"*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*"
)

fc <- file("repro_table3.md", open = "w")
writeLines(lines, fc)
close(fc)
RSCRIPT

# Run the R script inside the container
docker exec gilt_r_notebook /bin/bash --noprofile --norc -c "cd /home/jovyan/work && Rscript run_table3.R"

# Copy the generated table to the expected reproduction path
cp "${STUDY_DIR}/repro_table3.md" /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
