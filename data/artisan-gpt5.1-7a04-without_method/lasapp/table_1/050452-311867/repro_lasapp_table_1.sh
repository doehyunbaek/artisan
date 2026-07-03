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
# Section 3: Reproduction commands
cd lasapp-main/lasapp-main

# Python: total non-test LOC under src/py
py_total_nontest=$(find src/py -name '*.py' ! -path 'src/py/test/*' -print0 | xargs -0 wc -l | awk 'NF==2{sum+=$1} END{print sum}')

# Python PPL/back-end LOC from their binding files
py_pymc_loc=$(wc -l src/py/ppls/pymc.py | awk '{print $1}')
py_torch_loc=$(wc -l src/py/ppls/torch_distributions.py | awk '{print $1}')
py_pyro_loc=$(wc -l src/py/ppls/pyro.py | awk '{print $1}')
py_bean_loc=$(wc -l src/py/ppls/beanmachine.py | awk '{print $1}')

# Python language server LOC = total non-test - sum of PPL bindings
py_lang_loc=$((py_total_nontest - py_pymc_loc - py_torch_loc - py_pyro_loc - py_bean_loc))

# Julia: total non-test LOC under src/jl (exclude tests)
jl_total_nontest=$(find src/jl -name '*.jl' ! -path 'src/jl/test/*' -print0 | xargs -0 wc -l | awk 'NF==2{sum+=$1} END{print sum}')

# Julia PPL/back-end LOC from their binding files
jl_dist_loc=$(wc -l src/jl/ppls/distributions.jl | awk '{print $1}')
jl_gen_loc=$(wc -l src/jl/ppls/gen.jl | awk '{print $1}')
jl_turing_loc=$(wc -l src/jl/ppls/turing.jl | awk '{print $1}')

# Julia language server LOC = total non-test - sum of PPL bindings
jl_lang_loc=$((jl_total_nontest - jl_dist_loc - jl_gen_loc - jl_turing_loc))

# Write reproduction table
cat > /workspace/repro.txt <<EOREPRO
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | $py_lang_loc |                 |
| Python | PyMC [51]                | $py_pymc_loc | custom back-end |
| Python | torch.distributions [48] | $py_torch_loc | shared back-end |
| Python | Pyro [8]                 | $py_pyro_loc |                 |
| Python | BeanMachine [55]         | $py_bean_loc |                 |
| Julia  | Language Server          | $jl_lang_loc |                 |
| Julia  | Distributions.jl [7]     | $jl_dist_loc | shared back-end |
| Julia  | Gen [14]                 | $jl_gen_loc |                 |
| Julia  | Turing [21]              | $jl_turing_loc |                 |
EOREPRO

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
