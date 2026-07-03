#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Summaries of regressions estimating the effect of using the prototype. Each column summarizes the model for a different outcome variable. We report the coefficient estimates with the standard errors in parentheses.**

|                     |   Progress (1) |    Time (s) (2) |   Underst. (3) | Progress (Pros) | Progress (Students) |
| ------------------- | -------------: | --------------: | -------------: | --------------: | ------------------: |
| Constant            |    0.41 (0.49) | 312.65 (185.33) | -1.81** (0.89) |   -0.38 (0.68)  |      0.41** (0.20)  |
| Domain experience   |  0.13* (0.07)  |  23.14 (25.40)  | 0.41*** (0.12) |   0.16 (0.09)   |      0.09 (0.05)    |
| Program. experience | -0.10 (0.12)   | -23.67 (43.53)  |  -0.09 (0.14)  |   0.01 (0.17)   |    -0.18* (0.08)    |
| AI tool familiarity | -0.01 (0.07)   |   7.70 (27.04)  |  -0.09 (0.14)  |   0.07 (0.11)   |     -0.10 (0.10)    |
| Uses GILT           | 0.47*** (0.16) |  -9.10 (57.26)  |   0.29 (0.28)  | 0.57** (0.22)   |      0.46 (0.24)    |
| *R*²                |         0.173  |          0.022  |         0.137  |          0.341  |              0.137  |
| Adj. *R*²           |         0.104  |         -0.046  |         0.074  |          0.246  |              0.010  |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10461385
# Section 3: Reproduction commands (populate from reviewed steps)
# Run the regressions inside the jupyter/r-notebook Docker container and write a compact Table 1 summary to /workspace/repro.txt
docker run -d --init --entrypoint bash --name gilt-notebook -v /workspace/GILT_Artifacts/GILT_Artifacts-main/study:/home/jovyan/work jupyter/r-notebook -c 'sleep infinity'
docker exec gilt-notebook /bin/bash --noprofile --norc -c "R -q -e \"library(tidyverse); df <- read.csv('study_data.csv'); Q <- quantile(df\$success_time_no_guess, probs=c(.01,.99), na.rm=FALSE); elim_time <- subset(df, df\$success_time_no_guess >= Q[1] & df\$success_time_no_guess <= Q[2]); time_model <- lm(success_time_no_guess ~ tool + experience + recruiting.years + AI_experience, data=elim_time); Qp <- quantile(df\$progress_no_guess, probs=c(.01,.99), na.rm=FALSE); elim_prog <- subset(df, df\$progress_no_guess >= Qp[1] & df\$progress_no_guess <= Qp[2]); prog_all <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data=elim_prog, family=quasipoisson); Qs <- quantile(df\$understanding, probs=c(.01,.99), na.rm=FALSE); elim_under <- subset(df, df\$understanding >= Qs[1] & df\$understanding <= Qs[2]); under_model <- glm(understanding ~ tool + experience + recruiting.years + AI_experience, data=elim_under, family=quasipoisson); prog_pro <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data=elim_prog[elim_prog\$is_professional==1,], family=quasipoisson); prog_stu <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data=elim_prog[elim_prog\$is_professional==0,], family=quasipoisson); sink('/workspace/repro.txt'); cat('Progress (1) coefficients and SEs:\\n'); print(coef(summary(prog_all))); cat('\\nTime (2) coefficients and SEs:\\n'); print(coef(summary(time_model))); cat('\\nUnderstanding (3) coefficients and SEs:\\n'); print(coef(summary(under_model))); cat('\\nProgress (Pros) coefficients and SEs:\\n'); print(coef(summary(prog_pro))); cat('\\nProgress (Students) coefficients and SEs:\\n'); print(coef(summary(prog_stu))); cat('\\nR2 and adj R2:\\n'); cat('Time:', summary(time_model)\$r.squared, summary(time_model)\$adj.r.squared, '\\n'); library(rsq); cat('Understanding:', rsq(under_model), rsq(under_model, adj=TRUE), '\\n'); cat('Progress all:', rsq(prog_all), rsq(prog_all, adj=TRUE), '\\n'); cat('Progress pros:', rsq(prog_pro), rsq(prog_pro, adj=TRUE), '\\n'); cat('Progress students:', rsq(prog_stu), rsq(prog_stu, adj=TRUE), '\\n'); sink()\""
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
