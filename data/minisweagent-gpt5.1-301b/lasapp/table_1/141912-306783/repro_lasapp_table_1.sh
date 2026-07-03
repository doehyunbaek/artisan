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
set -e
cd /workspace
# Download main artifact (source + README)
curl -L https://zenodo.org/api/records/15857114/files/lasapp-main.zip/content -o lasapp-main.zip
unzip -q -o lasapp-main.zip -d lasapp-main
# Download prebuilt Docker image (amd64)
curl -L https://zenodo.org/api/records/15857114/files/lasapp-amd64.tar/content -o lasapp-amd64.tar
docker load -i lasapp-amd64.tar
# Start long-running container using modified run instruction
docker run -d --init --name lasapp-amd64 --rm --entrypoint bash lasapp-amd64 -c 'sleep infinity'

# Section 3: Reproduction commands (populate from reviewed steps)
# Run the LOC counting script inside the container and capture raw output
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "cd /LASAPP && julia evaluation/loc.jl" > /workspace/loc_raw.txt

# Aggregate LOCs to reproduce Table 1 entries
python_ls=$(awk -F': ' '/^src\/py\/analysis\// {a+=$2} /^src\/py\/ast_utils\// {b+=$2} END {print a+b}' /workspace/loc_raw.txt)
pymc=$(awk -F': ' '$1=="src/py/ppls/pymc.py"{p=$2} $1=="src/py/ppls/pyro_pymc_preproc.py"{q=$2} END{print p+q}' /workspace/loc_raw.txt)
torch=$(awk -F': ' '$1=="src/py/ppls/torch_distributions.py"{print $2}' /workspace/loc_raw.txt)
pyro=$(awk -F': ' '$1=="src/py/ppls/pyro.py"{p=$2} $1=="src/py/ppls/pyro_pymc_preproc.py"{q=$2} END{print p+q}' /workspace/loc_raw.txt)
bean=$(awk -F': ' '$1=="src/py/ppls/beanmachine.py"{print $2}' /workspace/loc_raw.txt)

julia_ls=$(awk -F': ' '/^src\/jl\/analysis\// {a+=$2} /^src\/jl\/ast\// {b+=$2} END {print a+b}' /workspace/loc_raw.txt)
dist=$(awk -F': ' '$1=="src/jl/ppls/distributions.jl"{print $2}' /workspace/loc_raw.txt)
gen=$(awk -F': ' '$1=="src/jl/ppls/gen.jl"{print $2}' /workspace/loc_raw.txt)
turing=$(awk -F': ' '$1=="src/jl/ppls/turing.jl"{print $2}' /workspace/loc_raw.txt)

# Write reproduced Table 1 to /workspace/repro.txt
cat > /workspace/repro.txt <<EOT
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
| Python | Language Server          | $python_ls |                 |
| Python | PyMC [51]                | $pymc | custom back-end |
| Python | torch.distributions [48] | $torch | shared back-end |
| Python | Pyro [8]                 | $pyro |                 |
| Python | BeanMachine [55]         | $bean |                 |
| Julia  | Language Server          | $julia_ls |                 |
| Julia  | Distributions.jl [7]     | $dist | shared back-end |
| Julia  | Gen [14]                 | $gen |                 |
| Julia  | Turing [21]              | $turing |                 |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
