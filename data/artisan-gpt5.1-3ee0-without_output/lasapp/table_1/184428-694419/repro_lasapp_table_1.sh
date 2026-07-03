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
# Use Julia to reproduce the LOC counting logic from evaluation/loc.jl
cat > /workspace/repro.txt <<'EOT'
**Table 1: Lines of code needed to add LASAPP support for various PPLs and probability distribution back-ends.**

|        | Back-end / PPL           | LOC  |                 |
| ---    | ---                      | ---  | ---             |
EOT
docker load -i lasapp-amd64.tar >/dev/null 2>&1 || true
docker rm -f lasapp-amd64 >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name lasapp-amd64 lasapp-amd64 -c 'sleep infinity' >/dev/null
docker exec lasapp-amd64 /bin/bash --noprofile --norc -c "julia -e '
function count_lines_of_code_in_file(filename)
    c = 0
    open(filename, \"r\") do f
        for line in split(read(f,String), \"\n\")
            if startswith(line, r\"\\s*#\")
                continue
            end
            if !contains(line, r\"[^\\s]+\")
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
py_ppl_pymc = count_lines_of_code_in_file(\"src/py/ppls/pymc.py\")
py_ppl_torch = count_lines_of_code_in_file(\"src/py/ppls/torch_distributions.py\")
py_ppl_pyro = count_lines_of_code_in_file(\"src/py/ppls/pyro.py\") + count_lines_of_code_in_file(\"src/py/ppls/pyro_pymc_preproc.py\") + count_lines_of_code_in_file(\"src/py/ppls/ppl.py\")
py_ppl_bean = count_lines_of_code_in_file(\"src/py/ppls/beanmachine.py\") + count_lines_of_code_in_file(\"src/py/ppls/ppl.py\")
jl_ls = count_lines_of_code_in_folder(\"src/jl/analysis\") + count_lines_of_code_in_folder(\"src/jl/ast\")
jl_dist = count_lines_of_code_in_file(\"src/jl/ppls/distributions.jl\")
jl_gen = count_lines_of_code_in_file(\"src/jl/ppls/gen.jl\")
jl_turing = count_lines_of_code_in_file(\"src/jl/ppls/turing.jl\")
open(\"/workspace/repro.txt\", \"a\") do f
    write(f, \"| Python | Language Server          | $(py_ls) |                 |\\n\")
    write(f, \"| Python | PyMC [51]                | $(py_ppl_pymc) | custom back-end |\\n\")
    write(f, \"| Python | torch.distributions [48] | $(py_ppl_torch) | shared back-end |\\n\")
    write(f, \"| Python | Pyro [8]                 | $(py_ppl_pyro) |                 |\\n\")
    write(f, \"| Python | BeanMachine [55]         | $(py_ppl_bean) |                 |\\n\")
    write(f, \"| Julia  | Language Server          | $(jl_ls) |                 |\\n\")
    write(f, \"| Julia  | Distributions.jl [7]     | $(jl_dist) | shared back-end |\\n\")
    write(f, \"| Julia  | Gen [14]                 | $(jl_gen) |                 |\\n\")
    write(f, \"| Julia  | Turing [21]              | $(jl_turing) |                 |\\n\")
end
'" 
docker rm -f lasapp-amd64 >/dev/null 2>&1 || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
