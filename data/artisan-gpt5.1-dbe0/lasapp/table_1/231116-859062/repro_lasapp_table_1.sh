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
docker load -i lasapp-amd64.tar
docker run -d --init --entrypoint bash --name lasapp-amd64-table1 --rm lasapp-amd64 -c 'sleep infinity'
docker exec lasapp-amd64-table1 /bin/bash --noprofile --norc -c "cd /LASAPP && cat >/tmp/loc_table.jl << 'JULIA'
function count_lines_of_code_in_file(filename)
    c = 0
    open(filename, \"r\") do f
        for line in split(read(f, String), \"\n\")
            if startswith(line, r\"\\s*#\")
                # comments
                continue
            end
            if !contains(line, r\"[^\\s]+\")
                # empty line
                continue
            end
            c += 1
        end
    end
    return c
end

function count_lines_of_code_in_folder(folder)
    c = 0
    for filename in readdir(folder; join=true)
        c += count_lines_of_code_in_file(filename)
    end
    return c
end

py_ls = count_lines_of_code_in_folder(\"src/py/analysis\") + count_lines_of_code_in_folder(\"src/py/ast_utils\")
pymc = count_lines_of_code_in_file(\"src/py/ppls/pymc.py\") + count_lines_of_code_in_file(\"src/py/ppls/pyro_pymc_preproc.py\")
torchd = count_lines_of_code_in_file(\"src/py/ppls/torch_distributions.py\")
pyro = count_lines_of_code_in_file(\"src/py/ppls/pyro.py\") + count_lines_of_code_in_file(\"src/py/ppls/pyro_pymc_preproc.py\")
bean = count_lines_of_code_in_file(\"src/py/ppls/beanmachine.py\")
jl_ls = count_lines_of_code_in_folder(\"src/jl/analysis\") + count_lines_of_code_in_folder(\"src/jl/ast\")
distjl = count_lines_of_code_in_file(\"src/jl/ppls/distributions.jl\")
gen = count_lines_of_code_in_file(\"src/jl/ppls/gen.jl\")
turing = count_lines_of_code_in_file(\"src/jl/ppls/turing.jl\")

println(\"**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**\\n\")
println(\"|        | Back-end / PPL           | LOC  |                 |\")
println(\"| ---    | ---                      | ---  | ---             |\")
println(\"| Python | Language Server          | \", py_ls, \" |                 |\")
println(\"| Python | PyMC [51]                | \", pymc, \" | custom back-end |\")
println(\"| Python | torch.distributions [48] | \", torchd, \" | shared back-end |\")
println(\"| Python | Pyro [8]                 | \", pyro, \" |                 |\")
println(\"| Python | BeanMachine [55]         | \", bean, \" |                 |\")
println(\"| Julia  | Language Server          | \", jl_ls, \" |                 |\")
println(\"| Julia  | Distributions.jl [7]     | \", distjl, \" | shared back-end |\")
println(\"| Julia  | Gen [14]                 | \", gen, \" |                 |\")
println(\"| Julia  | Turing [21]              | \", turing, \" |                 |\")
JULIA
julia --project=src/jl /tmp/loc_table.jl" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
