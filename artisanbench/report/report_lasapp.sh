docker run -i --rm --privileged -w /workspace doehyunbaek1/dind bash << 'EOF'
#!/usr/bin/bash
curl -L -o lasapp-amd64.tar "https://zenodo.org/records/15857114/files/lasapp-amd64.tar?download=1"

docker load -i lasapp-amd64.tar
docker run -d --init --entrypoint bash --name lasapp-amd64 lasapp-amd64 -c 'sleep infinity'
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "julia /LASAPP/evaluation/loc.jl" > /workspace/repro.txt 2>&1

# manually added
python3 - <<'PY' > /workspace/analyzed.txt
import re, sys

src = "/workspace/repro.txt"
pairs = {}
with open(src, "r", encoding="utf-8") as f:
    for line in f:
        m = re.match(r'(.+?):\s*(\d+)\s*$', line.strip())
        if m:
            pairs[m.group(1)] = int(m.group(2))

def sum_prefix(prefixes):
    return sum(loc for p, loc in pairs.items() if any(p.startswith(pr) for pr in prefixes))

# Python
py_lang = sum_prefix(["src/py/analysis/", "src/py/ast_utils/"])
py_pymc = pairs.get("src/py/ppls/pymc.py", 0) + pairs.get("src/py/ppls/pyro_pymc_preproc.py", 0)
py_torch = pairs.get("src/py/ppls/torch_distributions.py", 0)
py_pyro = pairs.get("src/py/ppls/pyro.py", 0) + pairs.get("src/py/ppls/pyro_pymc_preproc.py", 0)
py_bean = pairs.get("src/py/ppls/beanmachine.py", 0)

# Julia
jl_lang = sum_prefix(["src/jl/analysis/", "src/jl/ast/"])
jl_dist = pairs.get("src/jl/ppls/distributions.jl", 0)
jl_gen  = pairs.get("src/jl/ppls/gen.jl", 0)
jl_tur  = pairs.get("src/jl/ppls/turing.jl", 0)

rows = [
    ("Python", "Language Server",         py_lang, ""),
    ("",       "PyMC",                    py_pymc, "custom back-end"),
    ("",       "torch.distributions",     py_torch, "shared back-end"),
    ("",       "Pyro",                    py_pyro, ""),
    ("",       "BeanMachine",             py_bean, ""),
    ("Julia",  "Language Server",         jl_lang, ""),
    ("",       "Distributions.jl",        jl_dist, "shared back-end"),
    ("",       "Gen",                     jl_gen, ""),
    ("",       "Turing",                  jl_tur, ""),
]

print("**Table: Lines of code needed to add LASAPP support for various PPLs and distribution back-ends**\n")
print("|        | Back-end / PPL        |  LOC | Note |")
print("|--------|------------------------|-----:|------|")
for lang, name, loc, note in rows:
    print(f"| {lang} | {name} | {loc} | {note} |")
PY

echo '==========OUTPUT of /LASAPP/evaluation/loc.jl=========='
cat /workspace/repro.txt

echo '==========Aggregation of output=========='
cat /workspace/analyzed.txt
EOF
