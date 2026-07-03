#!/usr/bin/bash
set -euo pipefail

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

# Section 2: Artifact download (download only if missing)
[ -f /workspace/lasapp-main.zip ] || curl -L -o /workspace/lasapp-main.zip 'https://zenodo.org/records/15857114/files/lasapp-main.zip?download=1'

# Section 3: Reproduction commands
rm -rf /workspace/lasapp-main-extract || true
unzip -q /workspace/lasapp-main.zip -d /workspace/lasapp-main-extract

# The repo in the zip is under lasapp-main/lasapp-main
ROOT_DIR=/workspace/lasapp-main-extract/lasapp-main
if [ ! -d "$ROOT_DIR" ]; then
  # fallback if the archive layout differs
  ROOT_DIR=/workspace/lasapp-main-extract
fi

cd "$ROOT_DIR"

# Compute LOCs
python_ls_loc=$(find src/py -type f -name '*.py' ! -path '*/ppls/*' -print0 2>/dev/null | xargs -0 cat 2>/dev/null | wc -l || echo 0)
pymc_loc=$(wc -l < src/py/ppls/pymc.py 2>/dev/null || echo 0)
torch_loc=$(wc -l < src/py/ppls/torch_distributions.py 2>/dev/null || echo 0)
pyro_loc=$(wc -l < src/py/ppls/pyro.py 2>/dev/null || echo 0)
bean_loc=$(wc -l < src/py/ppls/beanmachine.py 2>/dev/null || echo 0)

julia_ls_loc=$(find src/jl -type f -name '*.jl' ! -path '*/ppls/*' -print0 2>/dev/null | xargs -0 cat 2>/dev/null | wc -l || echo 0)
dists_loc=$(wc -l < src/jl/ppls/distributions.jl 2>/dev/null || echo 0)
gen_loc=$(wc -l < src/jl/ppls/gen.jl 2>/dev/null || echo 0)
turing_loc=$(wc -l < src/jl/ppls/turing.jl 2>/dev/null || echo 0)

# Section 3 (continued): Write reproduction results to /workspace/repro.txt
cat > /workspace/repro.txt <<EOT
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | ${python_ls_loc} |                 |
| Python | PyMC [51]                | ${pymc_loc} | custom back-end |
| Python | torch.distributions [48] | ${torch_loc} | shared back-end |
| Python | Pyro [8]                 | ${pyro_loc} |                 |
| Python | BeanMachine [55]         | ${bean_loc} |                 |
| Julia  | Language Server          | ${julia_ls_loc} |                 |
| Julia  | Distributions.jl [7]     | ${dists_loc} | shared back-end |
| Julia  | Gen [14]                 | ${gen_loc} |                 |
| Julia  | Turing [21]              | ${turing_loc} |                 |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'

