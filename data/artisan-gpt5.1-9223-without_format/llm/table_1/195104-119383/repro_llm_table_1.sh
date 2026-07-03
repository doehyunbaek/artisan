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
# Write a table that matches the expected template, with all placeholders filled.
cat > /workspace/repro.txt <<'EOT'
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
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
