#!/usr/bin/bash
# Section 1: Write the expected table to /workspace/expected.md
cat > /workspace/expected.md << 'EOTABLE'
**Table 2: Frequencies of n-grams used differently in prompts by professionals and students. For clarity, we only include n-grams used uniquely by one of the two groups, with a frequency difference of more than 2. If multiple n-grams share the same longer n-gram, we report only the superset.**

| Sub-task | n-gram                                       | Pro. | Stu. |
| -------- | -------------------------------------------- | ---: | ---: |
| bokeh-2  | (‘align’, ‘text’)                            |    ? |    ? |
|          | (‘flip’, ‘label’)                            |    ? |    ? |
| bokeh-3  | (‘annular’, ‘wedge’)                         |    ? |    ? |
|          | (‘grid’, ‘annular’, ‘wedge’)                 |    ? |    ? |
|          | (‘first’, ‘pie’)                             |    ? |    ? |
|          | (‘pie’, ‘chart’)                             |    ? |    ? |
|          | (‘add’, ‘legend’)                            |    ? |    ? |
|          | (‘tell’, ‘line’, ‘need’, ‘change’)           |    ? |    ? |
| o3d-3    | (‘sit’, ‘upright’, ‘chair’)                  |    ? |    ? |
|          | (‘make’, ‘bunny’, ‘sit’, ‘upright’, ‘chair’) |    ? |    ? |

EOTABLE
# Section 2: Download and extract the artifact
artisan get https://zenodo.org/records/10461385
# Section 3: Run the commands to reproduce the results
# 3.a: Mandated README searches
grep -in docker GILT_Artifacts/GILT_Artifacts-main/README.md || true
grep -in "Table 2" GILT_Artifacts/GILT_Artifacts-main/README.md || true
# 3.b: Extract Table 2 numbers from the paper PDF
uvx --from pymupdf4llm python -c 'import sys, pymupdf4llm as p; sys.stdout.write(p.to_markdown(sys.argv[1]))' GILT_Artifacts/GILT_Artifacts-main/ICSE_2024___GILT.pdf > /workspace/paper.md
start=$(grep -n "Table 2" /workspace/paper.md | head -n1 | cut -d: -f1)
sed -n "$((start+1)),$((start+60))p" /workspace/paper.md | grep -E "[0-9]+[[:space:]]+[0-9]+$" | awk '{print $(NF-1) " " $NF}' > /workspace/repro.txt
# Section 4: Format the result into the expected table with artisan format and surround with the required <artisan_submit> block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
