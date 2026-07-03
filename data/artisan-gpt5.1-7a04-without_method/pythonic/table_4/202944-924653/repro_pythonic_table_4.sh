#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4: RQ1: Mixed-effect logistic regression relating the use of comprehensions with the correctness of the change task**

|                  |        |
| ---------------- | ------ |
| **AIC**          | ???.?  |
| **BIC**          | ???.?  |
| **logLik**       | -???.? |
| **deviance**     | ???.?  |
| **df.residuals** | ???    |

**Scaled residuals:** Min -1.64, 1Q -0.96, Median 0.62, 3Q 0.99, Max 1.59

**Random effects (Groups)** — User (Intercept): Variance 0, Std.Dev. 0; Number of obs: 386, groups: User, 192

**Fixed effects**

| Term | OR | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|---:|
| (Intercept) | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Compl. | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| Usage Freq. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ?.?? | ?.?? | ?.?? | ?.?? | ?.?? |
| MainFactorProc:Compl. | ?.?? | -?.?? | ?.?? | -?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts && \
  sh run-analysis.sh && \
  cat > /workspace/repro.txt <<'EOREPRO'
Generalized linear mixed model fit by maximum likelihood (Laplace
  Approximation) [glmerMod]
 Family: binomial  ( logit )
Formula: Outcome ~ MainFactor * Complexity + UsageFrequency + Approvals +  
    Student + (1 | User)
   Data: tComp
Control: 
glmerControl(optimizer = "nloptwrap", calc.derivs = FALSE, optCtrl = list(maxfun = 2e+06))

     AIC      BIC   logLik deviance df.resid 
   534.7    566.3   -259.3    518.7      378 

Scaled residuals: 
    Min      1Q  Median      3Q     Max 
-1.6396 -0.9616  0.6210  0.9891  1.5895 

Random effects:
 Groups Name        Variance Std.Dev.
 User   (Intercept) 0        0       
Number of obs: 386, groups:  User, 192

Fixed effects:
                         Estimate Std. Error z value Pr(>|z|)  
(Intercept)             0.1423928  0.8929099   0.159   0.8771  
MainFactorp             1.8097285  0.6027842   3.002   0.0188 *
Complexity              0.0174957  0.1131487   0.15    0.8771  
UsageFrequency         -0.1541288  0.1644872  -0.937   0.6103  
Approvals              -0.0003107  0.0002784  -1.116   0.6103  
StudentTRUE             0.1769830  0.6601219   0.268   0.8771  
MainFactorp:Complexity -0.4320469  0.1672648  -2.583   0.0343 *
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

Correlation of Fixed Effects:
            (Intr) MnFctr Cmplxt UsgFrq Apprvl StTRUE
MainFactorp -0.351                                   
Complexity  -0.473  0.623                            
UsageFrqncy -0.475 -0.005  0.004                     
Approvals   -0.103 -0.059  0.054 -0.031              
StudentTRUE -0.744  0.078  0.062 -0.008  0.017       
MnFctrp:Cmp  0.339 -0.938 -0.674  0.002  0.056 -0.083
EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
