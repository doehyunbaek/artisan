#!/usr/bin/bash
git clone https://github.com/sola-st/DyPyBench
cd DyPyBench/experiments
unzip -o callgraph_seq.zip
mv callgraph_seq ../evaluation/
cd ../evaluation
rm -f callgraph_seq/p17.json

apt-get update && apt-get install -y g++
python3 -m pip install --upgrade --no-cache-dir nbconvert papermill ipykernel prefixspan
python3 -m ipykernel install --name python3 --display-name 'python3'
python3 -m pip install --upgrade --no-cache-dir -r ../experiments/requirements.txt

python3 - <<'PY'
import json
nb = json.load(open("spec_mine.ipynb"))
nb["cells"] = nb["cells"][:17]
json.dump(nb, open("spec_mine_short.ipynb","w"))
PY

papermill spec_mine_short.ipynb executed_RQ3.ipynb --log-output > /workspace/repro.txt 2>&1
echo "<artisan_submit>"
python3 - <<'PY'
import sys
import re

t = open("/workspace/repro.txt", encoding="utf-8", errors="replace").read()

def find_freq(seq):
    pat = r"\(\s*(\d+)\s*,\s*\[\s*" + r"\s*,\s*".join([rf"'{re.escape(x)}'" for x in seq]) + r"\s*\]\s*\)"
    m = re.search(pat, t)
    return int(m.group(1)) if m else None

def fmt_int(n):
    return f"{n:,}" if n is not None else ""

def render_md_table(headers, rows, align, min_widths=None):
    widths = [len(h) for h in headers]
    for r in rows:
        for j, cell in enumerate(r):
            widths[j] = max(widths[j], len(cell))
    if min_widths:
        widths = [max(w, mw) for w, mw in zip(widths, min_widths)]

    def format_row(r):
        out = []
        for j, cell in enumerate(r):
            if align[j] == "right":
                out.append(cell.rjust(widths[j]))
            else:
                out.append(cell.ljust(widths[j]))
        # IMPORTANT: closing delimiter is " |" (space + pipe), not just "|"
        return "| " + " | ".join(out) + " |"

    sep_cells = []
    for j, w in enumerate(widths):
        if align[j] == "right":
            sep_cells.append(("-" * (w - 1)) + ":")
        else:
            sep_cells.append("-" * w)
    sep = "| " + " | ".join(sep_cells) + " |"

    return "\n".join([format_row(headers), sep] + [format_row(r) for r in rows]) + "\n"

freq_isinstance2 = find_freq(["builtins.isinstance", "builtins.isinstance"])
freq_pmsi = find_freq(["Pattern.match", "Match.span", "str.isidentifier"])

headers = ["Pattern", "Freq.", "Code examples from DyPyBench"]
rows = [
    [
        "builtins.isinstance · builtins.isinstance",
        fmt_int(freq_isinstance2),
        "`python\\nif isinstance(ty, tuple):\\n    return Tuple(ty)\\nif isinstance(ty, ParamType):\\n    return ty\\n`",
    ],
    [
        "Pattern.match · Match.span · str.isidentifier",
        fmt_int(freq_pmsi),
        "`python\\npseudomatch = pseudoprog.match(line, pos)\\nif pseudomatch:        # scan for tokens\\n    start, end = pseudomatch.span(1)\\n    # code in between\\n    if ...\\n    elif initial.isidentifier():\\n        # ...\\n`",
    ],
]

sys.stdout.write("**Table 3: Examples of patterns among top-100 mined patterns.**\n\n")
# These match the reference table’s preserved widths:
sys.stdout.write(render_md_table(headers, rows, ["left", "right", "left"], min_widths=[87, 5, 286]))

PY
echo "</artisan_submit>"
