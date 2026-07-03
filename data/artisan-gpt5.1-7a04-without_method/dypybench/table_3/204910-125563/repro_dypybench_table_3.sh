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
unzip -o callgraph_seq.zip >/dev/null
cd /workspace
python - <<'PY' > /workspace/repro.txt
import os, json, random

base = "/workspace/DyPyBench/experiments"
cg_dir = os.path.join(base, "callgraph_seq")

def split_by_callers(calls_sequence):
    counter = 1
    caller = calls_sequence[0].split("##")[-1]
    splitted_sequences = []
    s_temp = [calls_sequence[0]]
    i = 1
    while True:
        if i == len(calls_sequence):
            splitted_sequences.append(s_temp)
            break
        c = calls_sequence[i]
        if c.startswith("#START#"):
            if counter == 0 and c.split("##")[-1] != caller:
                splitted_sequences.append(s_temp)
                s_temp = [c]
                if i == len(calls_sequence):
                    splitted_sequences.append(s_temp)
                    break
                else:
                    caller = c
            else:
                s_temp.append(c)
            counter += 1
        elif c.startswith("#END#"):
            counter -= 1
            s_temp.append(c)
        i += 1
    return splitted_sequences

def generate_filtered_sequences(calls_seq):
    splitted_seqs = split_by_callers(calls_seq)
    final_list = []
    seq_calls = [calls_seq]
    while True:
        temp_seq = []
        for sc in seq_calls:
            temp_seq.extend(split_by_callers(sc))
        final_list.extend(temp_seq)
        seq_calls = []
        for s in temp_seq:
            if len(s) not in [0, 1, 2]:
                seq_calls.append(s[1:-1])
        if not seq_calls:
            break

    simple_final_list = []
    for l in final_list:
        simple_final_list.append([c.split("##")[0] for c in l])

    filtered_list = []
    for l in simple_final_list:
        if not l:
            continue
        if l[0].startswith("#END#"):
            continue
        new_l = []
        c_old = l[0].split("#")[2]
        for c in l[1:]:
            if c.split("#")[2] == c_old:
                new_l.append(c_old)
            c_old = c.split("#")[2]
        filtered_list.append(new_l)

    filtered_list = [f for f in filtered_list if len(f) >= 2]
    return filtered_list

traces = os.listdir(cg_dir)

all_sequences = []
sequence_by_project = []

random.seed(0)  # deterministic subsampling as described in the paper

for file in traces:
    path = os.path.join(cg_dir, file)
    try:
        with open(path) as dseq:
            seq_calls = json.load(dseq)
        fs = generate_filtered_sequences(seq_calls)
        # Apply same filtering as in plots_sec4.3.ipynb
        n_a_s = [e for e in fs if e.count('builtins.isinstance') <= 5]
        n_a_s = [s for s in n_a_s if len(s) < 100]
        if len(n_a_s) > 1893:
            random.shuffle(n_a_s)
            random.shuffle(n_a_s)
            use = n_a_s[:1893]
        else:
            use = n_a_s
        all_sequences.extend(use)
        sequence_by_project.append(use)
    except Exception:
        # Some JSONs (e.g., p17.json) are known to be problematic; skip them as in the original analysis
        continue

new_all_sequences = [e for e in all_sequences if e.count('builtins.isinstance') <= 5]
new_all_sequences = [s for s in new_all_sequences if len(s) < 100]

def support(pattern, sequences):
    sup = 0
    for seq in sequences:
        j = 0
        for token in seq:
            if token == pattern[j]:
                j += 1
                if j == len(pattern):
                    sup += 1
                    break
    return sup

p1 = ['builtins.isinstance', 'builtins.isinstance']
p2 = ['Pattern.match', 'Match.span', 'str.isidentifier']

s1 = support(p1, new_all_sequences)
s2 = support(p2, new_all_sequences)

freq1 = f"{s1:,}"
freq2 = f"{s2:,}"

print("**Table 3: Examples of patterns among top-100 mined patterns.**")
print()
print("| Pattern                                                                                 | Freq. | Code examples from DyPyBench                                                                                                                                                                                                   |")
print("| --------------------------------------------------------------------------------------- | ----: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |")
print(f"| builtins.isinstance · builtins.isinstance                                               | {freq1} | `python\\nif isinstance(ty, tuple):\\n    return Tuple(ty)\\nif isinstance(ty, ParamType):\\n    return ty\\n`                                                                                                                      |")
print(f"| Pattern.match · Match.span · str.isidentifier                                           | {freq2:>4} | `python\\npseudomatch = pseudoprog.match(line, pos)\\nif pseudomatch:        # scan for tokens\\n    start, end = pseudomatch.span(1)\\n    # code in between\\n    if ...\\n    elif initial.isidentifier():\\n        # ...\\n` |")
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
