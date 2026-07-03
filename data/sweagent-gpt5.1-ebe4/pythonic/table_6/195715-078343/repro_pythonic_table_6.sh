#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 6: RQ1: Logistic regression relating the use of map with the correctness of the change task (AIC=121)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | 16.48 | 1370.51 | 0.01 | 0.99 |
| MainFactorProc | 0.67 | 0.48 | 1.39 | 0.82 |
| Usage Freq. | -0.03 | 0.38 | -0.09 | 0.99 |
| Approvals | 0.00 | 0.00 | -0.07 | 0.99 |
| StudentTrue | -15.75 | 1370.51 | -0.01 | 0.99 |

EOTABLE
# Section 2: Artifact download
cd /workspace
curl -L 'https://zenodo.org/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip' -o ICSE2024-funcConstructs-Artifacts.zip
unzip -o ICSE2024-funcConstructs-Artifacts.zip
# Section 3: Reproduction commands (populate from reviewed steps)
# Run the provided R analysis script inside the Docker image to regenerate results tables
docker pull mdipenta/rexp:latest
CONTAINER_ID=$(docker run -d --init --entrypoint bash -v /workspace/ICSE2024-funcConstructs-Artifacts:/data mdipenta/rexp:latest -c 'sleep infinity')
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c 'cd /data && R --no-save < FuncConstructs-Statistics.r'
# Extract Table 6 (map logistic regression) coefficients to /workspace/repro.txt
cd /workspace/ICSE2024-funcConstructs-Artifacts/results
cp Table-6-RQ1-map.csv /workspace/repro.txt
# Stop container
docker stop "$CONTAINER_ID" >/dev/null
# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Format the CSV into a markdown-like table for inspection
python - << 'PYEOF'
import pandas as pd
from pathlib import Path

csv_path = Path('/workspace/repro.txt')
df = pd.read_csv(csv_path)
# Round to two decimals to match the paper presentation
rounded = df.round(2)
print('**Reproduced Table 6 coefficients (raw logistic regression output)**')
print()
print('| Term | Estimate | Std.Error | z value | Pr(>|z|) |')
print('|---|---:|---:|---:|---:|')
terms = ['(Intercept)', 'MainFactorProc', 'Usage Freq.', 'Approvals', 'StudentTrue']
for term, (_, row) in zip(terms, rounded.iterrows()):
    print(f"| {term} | {row['Estimate']} | {row['Std. Error']} | {row['z value']} | {row['Pr(>|z|)']} |")
PYEOF
echo '</artisan_submit>'
