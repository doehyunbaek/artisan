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
# Download the artifact from zenodo and unzip
curl -L 'https://zenodo.org/records/10461385/files/GILT_Artifacts.zip' -o /workspace/GILT_Artifacts.zip
unzip -q /workspace/GILT_Artifacts.zip -d /workspace || true

# Section 3: Reproduction commands
# Create an R script that runs the analyses for Table 1 and writes results to /workspace/repro.txt
cat > /workspace/run_table1.R <<'EOF'
# Minimal R script to reproduce Table 1 regressions
suppressPackageStartupMessages({
  # try to load rsq; if not available, we'll skip R^2 output
  available <- require(rsq, quietly=TRUE)
})

df_path <- Sys.getenv('STUDY_CSV', unset='/workspace/GILT_Artifacts/GILT_Artifacts-main/study/study_data.csv')
if(!file.exists(df_path)) stop(paste('Data file not found:', df_path))
df <- read.csv(df_path, header=TRUE)

fmt <- function(x) sprintf('%.2f', x)
star <- function(p) {
  if(is.na(p)) return('')
  if(p < 0.01) return('***')
  if(p < 0.05) return('**')
  if(p < 0.1) return('*')
  return('')
}

out <- file('/workspace/repro.txt','w')
writeLines('Reproduction of Table 1 models', out)

# Helper to extract coef and se and p
extract <- function(m, name) {
  s <- summary(m)$coefficients
  if(!(name %in% rownames(s))) return(c(NA,NA,NA))
  c(est = s[name,'Estimate'], se = s[name,'Std. Error'], p = s[name, ifelse(is.matrix(s), 'Pr(>|t|)', 'Pr(>|t|)')])
}

# 1) Time model (lm) using success_time_no_guess
Q <- quantile(df$success_time_no_guess, probs=c(.01,.99), na.rm=TRUE)
eliminated <- subset(df, df$success_time_no_guess >= Q[1] & df$success_time_no_guess <= Q[2])
# fit
time_model <- lm(success_time_no_guess ~ tool + experience + recruiting.years + AI_experience, data=eliminated)
sm <- summary(time_model)
writeLines('\nTime model (success_time_no_guess) - OLS', out)
coeffs <- sm$coefficients
vars <- c('(Intercept)','experience','recruiting.years','AI_experience','tool')
# Map names to expected order and labels
labels <- c('Constant','Domain experience','Program. experience','AI tool familiarity','Uses GILT')
for(i in seq_along(vars)){
  name <- vars[i]
  if(name %in% rownames(coeffs)){
    est <- coeffs[name,'Estimate']
    se  <- coeffs[name,'Std. Error']
    p   <- coeffs[name,'Pr(>|t|)']
    writeLines(paste(labels[i], sprintf(': %s (%s) %s', fmt(est), fmt(se), star(p))), out)
  } else {
    writeLines(paste(labels[i], ': NA'), out)
  }
}
writeLines(paste('R2:', if(available) sprintf('%.3f', rsq(time_model)) else 'NA'), out)
writeLines(paste('Adj.R2:', if(available) sprintf('%.3f', rsq(time_model, adj=TRUE)) else 'NA'), out)

# 2) Understanding model (quasipoisson glm)
Q <- quantile(df$understanding, probs=c(.01,.99), na.rm=TRUE)
eliminated <- subset(df, df$understanding >= Q[1] & df$understanding <= Q[2])
underst_model <- glm(understanding ~ tool + experience + recruiting.years + AI_experience, data=eliminated, family=quasipoisson)
smu <- summary(underst_model)
writeLines('\nUnderstanding model (understanding) - quasipoisson', out)
coeffs <- smu$coefficients
for(i in seq_along(vars)){
  name <- vars[i]
  if(name %in% rownames(coeffs)){
    est <- coeffs[name,'Estimate']
    se  <- coeffs[name,'Std. Error']
    p   <- coeffs[name,'Pr(>|t|)']
    writeLines(paste(labels[i], sprintf(': %s (%s) %s', fmt(est), fmt(se), star(p))), out)
  } else {
    writeLines(paste(labels[i], ': NA'), out)
  }
}
writeLines(paste('R2:', if(available) sprintf('%.3f', rsq(underst_model)) else 'NA'), out)
writeLines(paste('Adj.R2:', if(available) sprintf('%.3f', rsq(underst_model, adj=TRUE)) else 'NA'), out)

# 3) Progress model (quasipoisson glm)
Q <- quantile(df$progress_no_guess, probs=c(.01,.99), na.rm=TRUE)
eliminated <- subset(df, df$progress_no_guess >= Q[1] & df$progress_no_guess <= Q[2])
progress_model <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data=eliminated, family=quasipoisson)
smg <- summary(progress_model)
writeLines('\nProgress model (progress_no_guess) - quasipoisson', out)
coeffs <- smg$coefficients
for(i in seq_along(vars)){
  name <- vars[i]
  if(name %in% rownames(coeffs)){
    est <- coeffs[name,'Estimate']
    se  <- coeffs[name,'Std. Error']
    p   <- coeffs[name,'Pr(>|t|)']
    writeLines(paste(labels[i], sprintf(': %s (%s) %s', fmt(est), fmt(se), star(p))), out)
  } else {
    writeLines(paste(labels[i], ': NA'), out)
  }
}
writeLines(paste('R2:', if(available) sprintf('%.3f', rsq(progress_model)) else 'NA'), out)
writeLines(paste('Adj.R2:', if(available) sprintf('%.3f', rsq(progress_model, adj=TRUE)) else 'NA'), out)

# 4) Progress - Professionals (is_professional==1)
elim_p <- eliminated[eliminated$is_professional==1,]
if(nrow(elim_p) > 0){
  prog_p <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data=elim_p, family=quasipoisson)
  smp <- summary(prog_p)
  writeLines('\nProgress (Professionals)', out)
  coeffs <- smp$coefficients
  for(i in seq_along(vars)){
    name <- vars[i]
    if(name %in% rownames(coeffs)){
      est <- coeffs[name,'Estimate']
      se  <- coeffs[name,'Std. Error']
      p   <- coeffs[name,'Pr(>|t|)']
      writeLines(paste(labels[i], sprintf(': %s (%s) %s', fmt(est), fmt(se), star(p))), out)
    } else {
      writeLines(paste(labels[i], ': NA'), out)
    }
  }
  writeLines(paste('R2:', if(available) sprintf('%.3f', rsq(prog_p)) else 'NA'), out)
  writeLines(paste('Adj.R2:', if(available) sprintf('%.3f', rsq(prog_p, adj=TRUE)) else 'NA'), out)
} else {
  writeLines('\nProgress (Professionals): no professional rows after trimming', out)
}

# 5) Progress - Students (is_professional==0)
elim_s <- eliminated[eliminated$is_professional==0,]
if(nrow(elim_s) > 0){
  prog_s <- glm(progress_no_guess ~ tool + experience + recruiting.years + AI_experience, data=elim_s, family=quasipoisson)
  sms <- summary(prog_s)
  writeLines('\nProgress (Students)', out)
  coeffs <- sms$coefficients
  for(i in seq_along(vars)){
    name <- vars[i]
    if(name %in% rownames(coeffs)){
      est <- coeffs[name,'Estimate']
      se  <- coeffs[name,'Std. Error']
      p   <- coeffs[name,'Pr(>|t|)']
      writeLines(paste(labels[i], sprintf(': %s (%s) %s', fmt(est), fmt(se), star(p))), out)
    } else {
      writeLines(paste(labels[i], ': NA'), out)
    }
  }
  writeLines(paste('R2:', if(available) sprintf('%.3f', rsq(prog_s)) else 'NA'), out)
  writeLines(paste('Adj.R2:', if(available) sprintf('%.3f', rsq(prog_s, adj=TRUE)) else 'NA'), out)
} else {
  writeLines('\nProgress (Students): no student rows after trimming', out)
}

close(out)
EOF

# Run the R script (if R is available)
if command -v Rscript >/dev/null 2>&1; then
  Rscript /workspace/run_table1.R || true
else
  echo 'Rscript not found; please run /workspace/run_table1.R in an R environment to reproduce results' > /workspace/repro.txt
fi

# Section 4: Formatting and submission block
# Print the reproduction output for inspection
if [ -f /workspace/repro.txt ]; then
  echo '<artisan_submit>'
  sed -n '1,200p' /workspace/repro.txt
  echo '</artisan_submit>'
fi
