#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Examples of patterns among top-100 mined patterns.**

| Pattern                                                                                 | Freq. | Code examples from DyPyBench                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------------------- | ----: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| builtins.isinstance · builtins.isinstance                                               | ?,??? | `python\nif isinstance(ty, tuple):\n    return Tuple(ty)\nif isinstance(ty, ParamType):\n    return ty\n`                                                                                                                                                                                      |
| Pattern.match · Match.span · str.isidentifier                                           |   ??? | `python\npseudomatch = pseudoprog.match(line, pos)\nif pseudomatch:        # scan for tokens\n    start, end = pseudomatch.span(1)\n    # code in between\n    if ...\n    elif initial.isidentifier():\n        # ...\n`                                                                      |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/sola-st/DyPyBench

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/DyPyBench/experiments
unzip -o callgraph_seq.zip

python - << 'PY'
import os
import json
import random

# Load notebook to reuse authors' helper functions (split_by_callers, generate_filtered_sequences)
nb_path = "plots_sec4.3.ipynb"
with open(nb_path, "r", encoding="utf-8") as f:
    nb = json.load(f)

code_to_exec = []
for cell in nb.get("cells", []):
    if cell.get("cell_type") != "code":
        continue
    src = "".join(cell.get("source", []))
    if "def split_by_callers" in src or "def generate_filtered_sequences" in src:
        code_to_exec.append(src)

ns = {}
for src in code_to_exec:
    exec(src, ns)

if "split_by_callers" not in ns or "generate_filtered_sequences" not in ns:
    raise RuntimeError("Required functions not found in plots_sec4.3.ipynb")

split_by_callers = ns["split_by_callers"]
generate_filtered_sequences = ns["generate_filtered_sequences"]

traces_dir = "callgraph_seq"
traces = sorted(os.listdir(traces_dir))

all_sequences = []
sequence_by_project = []

for file in traces:
    path = os.path.join(traces_dir, file)
    try:
        with open(path, "r", encoding="utf-8") as dseq:
            seq_calls = json.load(dseq)

        fs = generate_filtered_sequences(seq_calls)
        n_a_s = [e for e in fs if e.count("builtins.isinstance") <= 5]
        n_a_s = [s for s in n_a_s if len(s) < 100]

        if len(n_a_s) > 1893:
            random.shuffle(n_a_s)
            random.shuffle(n_a_s)
            selected = n_a_s[:1893]
        else:
            selected = n_a_s

        all_sequences.extend(selected)
        sequence_by_project.append(selected)
    except Exception:
        # Ignore problematic files to match notebook's try/except behavior
        continue

new_all_sequences = [e for e in all_sequences if e.count("builtins.isinstance") <= 5]
new_all_sequences = [s for s in new_all_sequences if len(s) < 100]

def support(pattern, sequences):
    """Sequential pattern support: in how many sequences 'pattern' appears as a subsequence."""
    plen = len(pattern)
    count = 0
    for seq in sequences:
        j = 0
        for token in seq:
            if token == pattern[j]:
                j += 1
                if j == plen:
                    count += 1
                    break
    return count

pattern1 = ["builtins.isinstance", "builtins.isinstance"]
pattern2 = ["Pattern.match", "Match.span", "str.isidentifier"]

freq1 = support(pattern1, new_all_sequences)
freq2 = support(pattern2, new_all_sequences)

def fmt(n: int) -> str:
    return f"{n:,}"

f1 = fmt(freq1)
f2 = fmt(freq2)

repro_path = "/workspace/repro.txt"
with open(repro_path, "w", encoding="utf-8") as f:
    f.write("**Table 3: Examples of patterns among top-100 mined patterns.**\n\n")
    f.write("| Pattern                                                                                 | Freq. | Code examples from DyPyBench                                                                                                                                                                                                                                                                   |\n")
    f.write("| --------------------------------------------------------------------------------------- | ----: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |\n")
    f.write(f"| builtins.isinstance · builtins.isinstance                                               | {f1} | `python\\nif isinstance(ty, tuple):\\n    return Tuple(ty)\\nif isinstance(ty, ParamType):\\n    return ty\\n`                                                                                                                                                                                      |\n")
    f.write(f"| Pattern.match · Match.span · str.isidentifier                                           |   {f2} | `python\\npseudomatch = pseudoprog.match(line, pos)\\nif pseudomatch:        # scan for tokens\\n    start, end = pseudomatch.span(1)\\n    # code in between\\n    if ...\\n    elif initial.isidentifier():\\n        # ...\\n`                                                                      |\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
