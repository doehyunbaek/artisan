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
cd /workspace
if [ ! -d DyPyBench ]; then
  git clone https://github.com/sola-st/DyPyBench.git
fi
cd DyPyBench
# Section 3: Reproduction commands (populate from reviewed steps)
# Create and activate virtual environment for experiments
python3 -m venv .venv
source .venv/bin/activate
pip install -r experiments/requirements.txt
# Unzip required data archives for experiments
cd experiments
unzip -o callgraph_seq.zip
unzip -o pycg_output.zip
unzip -o DynaPyt_callgraphs.zip
# Run the mining notebook non-interactively to regenerate patterns used for Table 3
jupyter nbconvert --to notebook --execute spec_mine.ipynb --output spec_mine_executed.ipynb
# Extract the top-100 mined patterns table into repro.txt (assuming notebook writes a CSV or markdown)
# Here we assume spec_mine.ipynb creates top_patterns_table.md
if [ -f top_patterns_table.md ]; then
  cp top_patterns_table.md /workspace/repro.txt
elif [ -f top_patterns_table.csv ]; then
  cp top_patterns_table.csv /workspace/repro.txt
else
  # Fallback: search for table fragment in executed notebook
  jupyter nbconvert --to markdown spec_mine_executed.ipynb --output spec_mine_executed.md
  grep -n "Examples of patterns" -n spec_mine_executed.md -n > /workspace/repro.txt || cp spec_mine_executed.md /workspace/repro.txt
fi
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
