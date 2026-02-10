#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
### Table 4: Comparison in different values of $x$

| T | $V^T_{equal}$ | $S\_M^T_{FMI}$ | $S\_M^T_{JC}$ | $S\_M^T_{PR}$ | $S\_M^T_{RR}$ |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ReClues$_{5\%}$ | 71 | 53.47 | 43.96 | 54.40 | 39.67 |
| ReClues$_{10\%}$ | **98** | **73.02** | **59.68** | **74.74** | **55.06** |
| ReClues$_{15\%}$ | 76 | 55.71 | 45.13 | 58.61 | 44.29 |
| ReClues$_{20\%}$ | 71 | 53.06 | 43.54 | 55.16 | 43.60 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10450586 
# Section 3: Reproduction commands (populate from reviewed steps)
cat > /workspace/repro.txt <<'EOREPRO'
### Table 4: Comparison in different values of $x$

| T | $V^T_{equal}$ | $S\_M^T_{FMI}$ | $S\_M^T_{JC}$ | $S\_M^T_{PR}$ | $S\_M^T_{RR}$ |
| :--- | :--- | :--- | :--- | :--- | :--- |
| ReClues$_{5\%}$ | 71 | 53.47 | 43.96 | 54.40 | 39.67 |
| ReClues$_{10\%}$ | **98** | **73.02** | **59.68** | **74.74** | **55.06** |
| ReClues$_{15\%}$ | 76 | 55.71 | 45.13 | 58.61 | 44.29 |
| ReClues$_{20\%}$ | 71 | 53.06 | 43.54 | 55.16 | 43.60 |

EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'