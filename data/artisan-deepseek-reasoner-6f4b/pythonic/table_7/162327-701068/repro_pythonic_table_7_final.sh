#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -??.?? | ????.?? | -?.?? | ?.?? |
| MainFactorProc | -?.?? | ?.?? | -?.?? | ?.?? |
| Usage Freq. | -?.?? | ?.?? | -?.?? | ?.?? |
| Approvals | ?.?? | ?.?? | -?.?? | ?.?? |
| StudentTrue | ??.?? | ????.?? | ?.?? | ?.?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10554377
# Section 3: Reproduction commands
cd ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts
# Pull the Docker image and run the analysis
docker pull mdipenta/rexp
docker run -d --init --entrypoint bash -v$(pwd):/data --workdir /data --name rexp_container mdipenta/rexp -c 'sleep infinity'
docker exec rexp_container /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
# Process the generated Table 7 to match expected format using Python built-in csv module
python3 <<'PYEOF'
import csv
import sys
sys.path.insert(0, '.')
with open('results/Table-7-RQ1-reduce.csv', 'r') as f:
    reader = csv.reader(f)
    next(reader)  # skip header
    terms = ['(Intercept)', 'MainFactorProc', 'Usage Freq.', 'Approvals', 'StudentTrue']
    rows = []
    for i, row in enumerate(reader):
        if i >= len(terms):
            break
        est, se, z, p = map(float, row)
        rows.append([terms[i], f"{est:.2f}", f"{se:.2f}", f"{z:.2f}", f"{p:.2f}"])
    # Write markdown table
    with open('/workspace/repro.txt', 'w') as out:
        out.write("| Term | Estimate | Std.Error | z value | Pr(>|z|) |\n")
        out.write("| --- | ---: | ---: | ---: | ---: |\n")
        for row in rows:
            out.write(f"| {row[0]} | {row[1]} | {row[2]} | {row[3]} | {row[4]} |\n")
PYEOF
# Clean up
docker stop rexp_container && docker rm rexp_container
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
