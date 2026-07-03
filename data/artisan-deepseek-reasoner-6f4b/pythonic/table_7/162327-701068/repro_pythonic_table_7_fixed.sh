#!/usr/bin/bash
# Section 1: Expected table (unchanged)
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
# Process the generated Table 7 to match expected format
# Read the CSV, round to two decimals, and map term names
cat > process_table.py <<'PYEOF'
import pandas as pd
import sys
df = pd.read_csv('results/Table-7-RQ1-reduce.csv')
# Round to two decimal places
df = df.round(2)
# Map term names
terms = ['(Intercept)', 'MainFactorProc', 'Usage Freq.', 'Approvals', 'StudentTrue']
df.insert(0, 'Term', terms)
# Ensure columns order: Term, Estimate, Std.Error, z value, Pr(>|z|)
# Note: CSV has columns: Estimate, Std. Error, z value, Pr(>|z|)
df.columns = ['Term', 'Estimate', 'Std.Error', 'z value', 'Pr(>|z|)']
# Output as markdown table
output = df.to_markdown(index=False, floatfmt=".2f")
# Write to repro.txt
with open('/workspace/repro.txt', 'w') as f:
    f.write(output)
PYEOF
python3 process_table.py
# Clean up
docker stop rexp_container && docker rm rexp_container
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
