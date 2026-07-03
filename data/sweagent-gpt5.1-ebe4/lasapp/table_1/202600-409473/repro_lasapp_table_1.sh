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
cd /workspace
if [ ! -d lasapp_artifact ]; then
  curl -L https://zenodo.org/records/15857114/files/lasapp-main.zip -o lasapp-main.zip
  unzip -q lasapp-main.zip -d lasapp_artifact
fi
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/lasapp_artifact/lasapp-main
# For Table 1, the reported LOC correspond to counted lines in specific source directories/files.
# We reproduce them via cloc on the relevant paths, summing code lines only.
# Python language server LOC (src/py excluding ppls and test)
py_ls_loc=$(cloc src/py \
  --exclude-dir=ppls,test \
  --include-lang=Python \
  --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Python",{}).get("code",0))')
# Python PPL bindings
pymc_loc=$(cloc src/py/ppls/pymc.py --include-lang=Python --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Python",{}).get("code",0))')
torch_loc=$(cloc src/py/ppls/torch_distributions.py --include-lang=Python --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Python",{}).get("code",0))')
pyro_loc=$(cloc src/py/ppls/pyro.py --include-lang=Python --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Python",{}).get("code",0))')
bean_loc=$(cloc src/py/ppls/beanmachine.py --include-lang=Python --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Python",{}).get("code",0))')
# Julia language server LOC (src/jl excluding ppls and test)
jl_ls_loc=$(cloc src/jl \
  --exclude-dir=ppls,test \
  --include-lang=Julia \
  --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Julia",{}).get("code",0))')
# Julia PPL bindings
jldist_loc=$(cloc src/jl/ppls/distributions.jl --include-lang=Julia --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Julia",{}).get("code",0))')
jlgen_loc=$(cloc src/jl/ppls/gen.jl --include-lang=Julia --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Julia",{}).get("code",0))')
jlturing_loc=$(cloc src/jl/ppls/turing.jl --include-lang=Julia --json 2>/dev/null | python -c 'import sys, json; d=json.load(sys.stdin); print(d.get("Julia",{}).get("code",0))')
# Save reproduction results
cat > /workspace/repro.txt <<EOREPRO
Python Language Server LOC: $py_ls_loc
Python PyMC LOC: $pymc_loc
Python torch.distributions LOC: $torch_loc
Python Pyro LOC: $pyro_loc
Python BeanMachine LOC: $bean_loc
Julia Language Server LOC: $jl_ls_loc
Julia Distributions.jl LOC: $jldist_loc
Julia Gen LOC: $jlgen_loc
Julia Turing LOC: $jlturing_loc
EOREPRO
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format reproduction results as a markdown table similar to Table 1
python - <<'EOPY'
import pathlib
repro = {}
with open('/workspace/repro.txt') as f:
    for line in f:
        if ':' not in line:
            continue
        k, v = line.strip().split(':', 1)
        repro[k.strip()] = v.strip()
rows = [
    ("Python", "Language Server", repro.get("Python Language Server LOC", ""), ""),
    ("Python", "PyMC [51]", repro.get("Python PyMC LOC", ""), "custom back-end"),
    ("Python", "torch.distributions [48]", repro.get("Python torch.distributions LOC", ""), "shared back-end"),
    ("Python", "Pyro [8]", repro.get("Python Pyro LOC", ""), ""),
    ("Python", "BeanMachine [55]", repro.get("Python BeanMachine LOC", ""), ""),
    ("Julia", "Language Server", repro.get("Julia Language Server LOC", ""), ""),
    ("Julia", "Distributions.jl [7]", repro.get("Julia Distributions.jl LOC", ""), "shared back-end"),
    ("Julia", "Gen [14]", repro.get("Julia Gen LOC", ""), ""),
    ("Julia", "Turing [21]", repro.get("Julia Turing LOC", ""), ""),
]
print("**Reproduced Table 1 LOC counts from artifact.**\n")
print("|        | Back-end / PPL           | LOC  |                 |")
print("| ---    | ---                      | ---  | ---             |")
for lang, backend, loc, note in rows:
    print(f"| {lang:<6}| {backend:<24}| {loc:<4}| {note:<15}|")
EOPY
echo '</artisan_submit>'
