#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Examples of patterns among top-100 mined patterns.**

| Pattern                                                                                 | Freq. | Code examples from DyPyBench                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------------------- | ----: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| builtins.isinstance · builtins.isinstance                                               | 1,701 | `python\nif isinstance(ty, tuple):\n    return Tuple(ty)\nif isinstance(ty, ParamType):\n    return ty\n`                                                                                                                                                                                      |
| Pattern.match · Match.span · str.isidentifier                                           |   730 | `python\npseudomatch = pseudoprog.match(line, pos)\nif pseudomatch:        # scan for tokens\n    start, end = pseudomatch.span(1)\n    # code in between\n    if ...\n    elif initial.isidentifier():\n        # ...\n`                                                                      |

EOTABLE

# Section 2: Artifact download
# Clone the DyPyBench repository (if not already present)
if [ ! -d /workspace/DyPyBench ]; then
    git clone https://github.com/sola-st/DyPyBench /workspace/DyPyBench
else
    echo "DyPyBench repo already exists, skipping clone."
fi

# Section 3: Reproduction commands
set -u
cd /workspace/DyPyBench/experiments
# Unzip required experiment data
unzip -o DynaPyt_output.zip -d . || true
unzip -o callgraph_seq.zip -d . || true

# Run a Python script that follows the notebook's preprocessing and a simple n-gram mining pipeline
python3 - <<'PY'
import json, glob
from collections import Counter

# implement split_by_callers from notebook

def split_by_callers(calls_sequence):
    counter = 1
    caller = calls_sequence[0].split("##")[-1]
    splitted_sequences = []
    s_temp = []
    s_temp.append(calls_sequence[0])
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
        else:
            s_temp.append(c)
        i = i + 1
    return splitted_sequences

# iterate over callgraph_seq files and collect sequences following the notebook logic
all_sequences = []
for pfn in glob.glob('callgraph_seq/p*.json'):
    with open(pfn) as f:
        seq_calls = json.load(f)
    # follow notebook pipeline
    splitted_seqs = split_by_callers(seq_calls)
    final_list = []
    seq_calls_list = [seq_calls]
    while True:
        temp_seq = []
        for sc in seq_calls_list:
            temp_seq.extend(split_by_callers(sc))
        final_list.extend(temp_seq)
        seq_calls_list = []
        for s in temp_seq:
            if len(s) not in [0,1,2]:
                seq_calls_list.append(s[1:-1])
        if len(seq_calls_list) == 0:
            break
    simple_final_list = []
    for l in final_list:
        simple_final_list.append([c.split("##")[0] for c in l])
    # filter sequences similar to notebook
    filtered_list = []
    for l in simple_final_list:
        try:
            new_l = []
            while l and l[0].startswith("#END#"):
                l = l[1:]
            if not l:
                continue
            c_old = l[0].split("#")[2]
            for c in l[1:]:
                if c.split("#")[2] == c_old:
                    new_l.append(c_old)
                c_old = c.split("#")[2]
            filtered_list.append(new_l)
        except Exception:
            continue
    filtered_list = [f for f in filtered_list if len(f) >= 2]
    all_sequences.extend(filtered_list)

print('Collected sequences:', len(all_sequences))
if len(all_sequences) == 0:
    print('No sequences found, exiting')
    raise SystemExit(1)

# Simple n-gram mining (count contiguous subsequences of length 2..6)
counter = Counter()
for seq in all_sequences:
    L = len(seq)
    for k in range(2, min(7, L+1)):
        for i in range(L - k + 1):
            ng = tuple(seq[i:i+k])
            counter[ng] += 1

# write top 100 to repro file
with open('/workspace/repro.txt','w') as out:
    out.write('Pattern\tFreq\n')
    for ng, freq in counter.most_common(100):
        pat = ' · '.join(ng)
        out.write(f"{pat}\t{freq}\n")
print('Wrote /workspace/repro.txt')
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt || true
echo '</artisan_submit>'

# Do not auto-submit; signal completion
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
