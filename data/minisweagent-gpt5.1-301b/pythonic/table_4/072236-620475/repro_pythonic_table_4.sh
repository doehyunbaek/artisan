#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | 534.7  |
| **BIC**          | 566.3  |
| **logLik**       | -259.3 |
| **deviance**     | 518.7  |
| **df.residuals** | 378    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | 1.15 | 0.14 | 0.89 | 0.16 | 0.88 |
| MainFactorProc | 6.11 | 1.81 | 0.60 | 3.00 | 0.02 |
| Compl. | 1.02 | 0.02 | 0.11 | 0.15 | 0.88 |
| Usage Freq. | 0.86 | -0.15 | 0.16 | -0.94 | 0.61 |
| Approvals | 1.00 | -0.00 | 0.00 | -1.12 | 0.61 |
| StudentTrue | 1.19 | 0.18 | 0.66 | 0.27 | 0.88 |
| MainFactorProc:Compl. | 0.65 | -0.43 | 0.17 | -2.58 | 0.03 |

EOTABLE

# Section 2: Artifact download
ARTIFACT_DIR="/workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts"
ZIP_PATH="/workspace/ICSE2024-funcConstructs-Artifacts.zip"

if [ ! -d "$ARTIFACT_DIR" ]; then
  mkdir -p /workspace/ICSE2024-funcConstructs-Artifacts
  if [ ! -f "$ZIP_PATH" ]; then
    curl -L "https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip" -o "$ZIP_PATH"
  fi
  unzip -d /workspace/ICSE2024-funcConstructs-Artifacts "$ZIP_PATH"
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd "$ARTIFACT_DIR"

# Ensure the Docker image is present
docker pull mdipenta/rexp

# Start a long-lived container for running R, replacing any previous one
docker rm -f funcstats || true
docker run -d --init --entrypoint bash --name funcstats -v "${PWD}:/data" -w /data mdipenta/rexp -c 'sleep infinity'

# Run the full analysis script to regenerate all tables and figures
docker exec funcstats /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Fit the comprehension mixed-effects model and emit a markdown reproduction of Table 4
docker exec funcstats /bin/bash --noprofile --norc -c 'cd /data && R --vanilla -q' <<'RSCRIPT' > /workspace/repro.txt
suppressPackageStartupMessages({
  library(lme4)
})

inputDir <- "working-results/RQ1-RQ2-files-for-statistical-analysis"
t <- read.csv(file.path(inputDir, "RQ1.csv"))

# Match the preprocessing used in FuncConstructs-Statistics.r
t$Complexity <- t$Complexity + 1
tComp <- subset(t, Section == "comp" & UsageFrequency > 1)
tComp <- droplevels(tComp)

model <- glmer(
  Outcome ~ MainFactor * Complexity + UsageFrequency + Approvals + Student + (1 | User),
  data = tComp,
  family = "binomial",
  control = glmerControl(optimizer = "nloptwrap", calc.derivs = FALSE, optCtrl = list(maxfun = 2e6))
)

smod <- summary(model)
# Apply BH adjustment, as in the authors' script
smod$coefficients[, 4] <- p.adjust(smod$coefficients[, 4], method = "BH")
mc <- smod$coefficients
OR <- exp(mc[, "Estimate"])

# Model fit statistics
aic  <- AIC(model)
bic  <- BIC(model)
ll   <- as.numeric(logLik(model))
dev  <- deviance(model)
dfre <- df.residual(model)

# Scaled residuals (use deviance residuals for consistency with summary output)
sr <- residuals(model)
qs <- quantile(sr, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)

# Random effect for User
vc <- as.data.frame(VarCorr(model))
var_user <- vc[vc$grp == "User", "vcov"]
sd_user  <- vc[vc$grp == "User", "sdcor"]
nobs  <- nrow(tComp)
ngrp  <- length(unique(tComp$User))

fmt1 <- function(x) sprintf("%.1f", round(x, 1))
fmt2 <- function(x) sprintf("%.2f", round(x, 2))

# Map coefficient names to the labels used in the paper
terms_raw <- rownames(mc)
terms_print <- terms_raw
terms_print[terms_raw == "(Intercept)"] <- "(Intercept)"
terms_print[grep("^MainFactor", terms_raw)] <- "MainFactorProc"
terms_print[terms_raw == "Complexity"] <- "Compl."
terms_print[terms_raw == "UsageFrequency"] <- "Usage Freq."
terms_print[grep("^Student", terms_raw)] <- "StudentTrue"
terms_print[grep("^MainFactor.*:Complexity", terms_raw)] <- "MainFactorProc:Compl."

# Header
cat("**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**\n\n")

cat("|                  |        |\n")
cat("| ---------------- | ------ |\n")
cat("| **AIC**          | ", fmt1(aic), "  |\n", sep = "")
cat("| **BIC**          | ", fmt1(bic), "  |\n", sep = "")
cat("| **logLik**       | ", fmt1(ll), " |\n", sep = "")
cat("| **deviance**     | ", fmt1(dev), "  |\n", sep = "")
cat("| **df.residuals** | ", dfre, "    |\n\n", sep = "")

cat("**Scaled residuals:** Min ", fmt2(qs[1]), ", 1Q ", fmt2(qs[2]),
    ", Median ", fmt2(qs[3]), ", 3Q ", fmt2(qs[4]),
    ", Max ", fmt2(qs[5]), "\n\n", sep = "")

# Random effects line
var_str <- if (is.finite(var_user)) formatC(var_user, format = "f", digits = 0) else "NA"
sd_str  <- if (is.finite(sd_user))  formatC(sd_user,  format = "f", digits = 0) else "NA"
cat("**Random effects (Groups)** — User (Intercept): Variance ", var_str,
    ", Std.Dev. ", sd_str, "; Number of obs: ", nobs,
    ", groups: User, ", ngrp, "\n\n", sep = "")

cat("**Fixed effects**\n\n")
cat("| Term | OR | Estimate | Std.Error | z value | Pr(>|z|) |\n")
cat("|---|---:|---:|---:|---:|---:|\n")

pvals <- mc[, "Pr(>|z|)"]
for (i in seq_len(nrow(mc))) {
  cat("| ", terms_print[i],
      " | ", fmt2(OR[i]),
      " | ", fmt2(mc[i, "Estimate"]),
      " | ", fmt2(mc[i, "Std. Error"]),
      " | ", fmt2(mc[i, "z value"]),
      " | ", fmt2(pvals[i]),
      " |\n", sep = "")
}
RSCRIPT

# Clean up the container
docker rm -f funcstats || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
