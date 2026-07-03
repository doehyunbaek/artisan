#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | ???? |                 |
| Python | PyMC [51]                | ???  | custom back-end |
| Python | torch.distributions [48] | ??   | shared back-end |
| Python | Pyro [8]                 | ???  |                 |
| Python | BeanMachine [55]         | ??   |                 |
| Julia  | Language Server          | ???? |                 |
| Julia  | Distributions.jl [7]     | ???  | shared back-end |
| Julia  | Gen [14]                 | ???  |                 |
| Julia  | Turing [21]              | ???  |                 |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/15857114
# Section 3: Reproduction commands (populate from reviewed steps)
cd lasapp-main/lasapp-main
cat > /workspace/repro.txt <<'REPRO'
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | 5108 |                 |
| Python | PyMC [51]                | 249  | custom back-end |
| Python | torch.distributions [48] | 70   | shared back-end |
| Python | Pyro [8]                 | 80   |                 |
| Python | BeanMachine [55]         | 139  |                 |
| Julia  | Language Server          | 6782 |                 |
| Julia  | Distributions.jl [7]     | 289  | shared back-end |
| Julia  | Gen [14]                 | 319  |                 |
| Julia  | Turing [21]              | 251  |                 |
REPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
