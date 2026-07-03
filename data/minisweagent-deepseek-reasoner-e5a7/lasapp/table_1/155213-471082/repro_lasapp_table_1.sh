#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | 1553 |                 |
| Python | PyMC [51]                | 281  | custom back-end |
| Python | torch.distributions [48] | 67   | shared back-end |
| Python | Pyro [8]                 | 133  |                 |
| Python | BeanMachine [55]         | 95   |                 |
| Julia  | Language Server          | 2175 |                 |
| Julia  | Distributions.jl [7]     | 240  | shared back-end |
| Julia  | Gen [14]                 | 227  |                 |
| Julia  | Turing [21]              | 172  |                 |

EOTABLE
# Section 2: Artifact download
# Already downloaded in previous steps
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/lasapp-main/lasapp-main

# Compute LOC for each component
PYTHON_LS_LOC=$(find src/static -type f -name "*.py" ! -path "*/test/*" -exec cat {} \; | wc -l)
PYMC_LOC=$(wc -l < src/py/ppls/pymc.py)
TORCH_LOC=$(wc -l < src/py/ppls/torch_distributions.py)
PYRO_LOC=$(wc -l < src/py/ppls/pyro.py)
BEANMACHINE_LOC=$(wc -l < src/py/ppls/beanmachine.py)
JULIA_LS_LOC=$(find src/jl -type f -name "*.jl" ! -path "*/ppls/*" ! -path "*/test/*" -exec cat {} \; | wc -l)
DISTRIBUTIONS_JL_LOC=$(wc -l < src/jl/ppls/distributions.jl)
GEN_LOC=$(wc -l < src/jl/ppls/gen.jl)
TURING_LOC=$(wc -l < src/jl/ppls/turing.jl)

# Output reproduction results to /workspace/repro.txt
cat > /workspace/repro.txt <<EOREPRO
Python Language Server LOC: $PYTHON_LS_LOC
PyMC LOC: $PYMC_LOC
torch.distributions LOC: $TORCH_LOC
Pyro LOC: $PYRO_LOC
BeanMachine LOC: $BEANMACHINE_LOC
Julia Language Server LOC: $JULIA_LS_LOC
Distributions.jl LOC: $DISTRIBUTIONS_JL_LOC
Gen LOC: $GEN_LOC
Turing LOC: $TURING_LOC
EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
echo '**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**'
echo ''
echo '|        | Back-end / PPL           | LOC  |                 |'
echo '| ---    | ---                      | ---  | ---             |'
echo "| Python | Language Server          | $PYTHON_LS_LOC |                 |"
echo "| Python | PyMC [51]                | $PYMC_LOC  | custom back-end |"
echo "| Python | torch.distributions [48] | $TORCH_LOC   | shared back-end |"
echo "| Python | Pyro [8]                 | $PYRO_LOC  |                 |"
echo "| Python | BeanMachine [55]         | $BEANMACHINE_LOC   |                 |"
echo "| Julia  | Language Server          | $JULIA_LS_LOC |                 |"
echo "| Julia  | Distributions.jl [7]     | $DISTRIBUTIONS_JL_LOC  | shared back-end |"
echo "| Julia  | Gen [14]                 | $GEN_LOC  |                 |"
echo "| Julia  | Turing [21]              | $TURING_LOC  |                 |"
echo '</artisan_submit>'
