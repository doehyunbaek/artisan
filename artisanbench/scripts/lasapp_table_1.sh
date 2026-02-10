#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o lasapp-main.zip \
  https://zenodo.org/api/records/15857114/files/lasapp-main.zip/content

unzip -o lasapp-main.zip -d lasapp-main
cd /workspace/lasapp-main/lasapp-main

python3 - << 'PY'
import os, re

def count_loc_file(path):
    c = 0
    with open(path, 'r', encoding='utf-8') as f:
        for line in f.read().splitlines():
            if re.match(r"\s*#", line):
                # comments
                continue
            if not re.search(r"\S", line):
                # empty line
                continue
            c += 1
    return c

def count_loc_dir(path):
    total = 0
    for name in sorted(os.listdir(path)):
        fp = os.path.join(path, name)
        if os.path.isfile(fp):
            total += count_loc_file(fp)
    return total

# Python language server: analysis + ast_utils
py_ls = count_loc_dir("src/py/analysis") + count_loc_dir("src/py/ast_utils")

# Python PPL / back-end bindings
# Count the shared Pyro/PyMC preprocessor as contributing to both PyMC and Pyro.
shared_pre = count_loc_file("src/py/ppls/pyro_pymc_preproc.py")
py_pymc = count_loc_file("src/py/ppls/pymc.py") + shared_pre
py_torch = count_loc_file("src/py/ppls/torch_distributions.py")
py_pyro = count_loc_file("src/py/ppls/pyro.py") + shared_pre
py_bean = count_loc_file("src/py/ppls/beanmachine.py")

# Julia language server: analysis + ast
jl_ls = count_loc_dir("src/jl/analysis") + count_loc_dir("src/jl/ast")

# Julia PPL / back-end bindings
jl_dist = count_loc_file("src/jl/ppls/distributions.jl")
jl_gen = count_loc_file("src/jl/ppls/gen.jl")
jl_turing = count_loc_file("src/jl/ppls/turing.jl")

out_path = "/workspace/repro.txt"
with open(out_path, "w", encoding="utf-8") as out:
    out.write("**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**\n\n")
    out.write("|        | Back-end / PPL           | LOC  |                 |\n")
    out.write("| ---    | ---                      | ---  | ---             |\n")
    out.write(f"| Python | Language Server          | {py_ls} |                 |\n")
    out.write(f"| Python | PyMC [51]                | {py_pymc} | custom back-end |\n")
    out.write(f"| Python | torch.distributions [48] | {py_torch} | shared back-end |\n")
    out.write(f"| Python | Pyro [8]                 | {py_pyro} |                 |\n")
    out.write(f"| Python | BeanMachine [55]         | {py_bean} |                 |\n")
    out.write(f"| Julia  | Language Server          | {jl_ls} |                 |\n")
    out.write(f"| Julia  | Distributions.jl [7]     | {jl_dist} | shared back-end |\n")
    out.write(f"| Julia  | Gen [14]                 | {jl_gen} |                 |\n")
    out.write(f"| Julia  | Turing [21]              | {jl_turing} |                 |\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
