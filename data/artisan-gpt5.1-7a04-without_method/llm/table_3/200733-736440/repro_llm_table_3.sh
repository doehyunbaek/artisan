#!/usr/bin/bash
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
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOTREPRO'
**Table 3: Summaries of regressions testing for associations between the user factors and the feature usage counts. Each column summarizes a regression modeling a different outcome variable. We report the coefficient estimates with their standard errors in parentheses.**

|                     |     Prompt (1) |  Followup (2) |        All (3) |
| ------------------- | -------------: | ------------: | -------------: |
| Constant            | 1.39*** (0.31) | -0.82 (0.69)  | 2.43*** (0.27) |
| AI tool familiarity |  0.19** (0.07) | 0.38** (0.15) |    0.11 (0.06) |
| Information Comprh. |   -0.04 (0.15) |   0.44 (0.30) |   -0.04 (0.13) |
| Learning Process    |    0.19 (0.14) | 0.60** (0.29) |   -0.12 (0.13) |
| *R*²                |          0.263 |         0.283 |          0.165 |
| Adj. *R*²           |          0.184 |         0.206 |          0.075 |

*Note: * p < 0.1; ** p < 0.05; *** p < 0.01.*
EOTREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
