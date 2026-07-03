#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -15.80 | 1383.44 | 0.01 | 0.99 |
| MainFactorProc | -0.06 | 0.40 | -0.16 | 0.99 |
| Usage Freq. | -0.18 | 0.33 | -0.54 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.76 | 0.99 |
| StudentTrue | 15.56 | 1383.44 | 0.01 | 0.99 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip -o artifact.zip
unzip -o artifact.zip -d artifact_dir
# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact_dir/ICSE2024-funcConstructs-Artifacts
# Start docker container with mounted artifact directory
CONTAINER_ID=$(docker run -d --init --entrypoint bash -v"${PWD}":/data mdipenta/rexp:latest -c 'sleep infinity')
# Run the R analysis script inside the container to regenerate tables
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r" > /workspace/repro.log 2>&1
# Copy the generated Table 8 CSV to a stable location and format it as markdown
cp /workspace/artifact_dir/ICSE2024-funcConstructs-Artifacts/results/Table-8-RQ1-filter.csv /workspace/table8.csv
# Stop container
docker rm -f "$CONTAINER_ID" >/dev/null 2>&1
# Produce a markdown table into /workspace/repro.txt
python - << 'PYEOF'
import csv, pathlib
inp = pathlib.Path('/workspace/table8.csv')
outp = pathlib.Path('/workspace/repro.txt')
rows = list(csv.reader(inp.read_text().splitlines()))
header = ['Term'] + rows[0]
terms = ['(Intercept)','MainFactorProc','Usage Freq.','Approvals','StudentTrue']
lines = []
lines.append('**Table 8: RQ1: Logistic regression relating the use of filter with the correctness of the change task (AIC=157)**\n')
lines.append('\n| ' + ' | '.join(header) + ' |')
lines.append('|---|' + '---:|'*len(rows[0]))
for term, vals in zip(terms, rows[1:]):
    est, se, z, p = map(float, vals)
    lines.append(f"| {term} | {est:.2f} | {se:.2f} | {z:.2f} | {p:.2f} |")
outp.write_text('\n'.join(lines) + '\n')
PYEOF
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
