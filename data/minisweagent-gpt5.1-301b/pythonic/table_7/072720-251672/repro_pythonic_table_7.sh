#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**

| Term | Estimate | Std.Error | z value | Pr(>\|z\|) |
|---|---:|---:|---:|---:|
| (Intercept) | -13.20 | 1696.36 | -0.01 | 0.99 |
| MainFactorProc | -0.26 | 0.47 | -0.56 | 0.99 |
| Usage Freq. | -0.83 | 0.44 | -1.87 | 0.30 |
| Approvals | 0.00 | 0.00 | -0.36 | 0.99 |
| StudentTrue | 14.38 | 1696.36 | 0.01 | 0.99 |

EOTABLE

# Section 2: Artifact download
cd /workspace
if [ ! -f ICSE2024-funcConstructs-Artifacts.zip ]; then
  curl -L -o ICSE2024-funcConstructs-Artifacts.zip 'https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content'
fi
if [ ! -d artifact/ICSE2024-funcConstructs-Artifacts ]; then
  mkdir -p artifact
  unzip -d artifact ICSE2024-funcConstructs-Artifacts.zip
fi

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace/artifact/ICSE2024-funcConstructs-Artifacts

# Ensure the Docker image is available
docker pull mdipenta/rexp

# Start a long-running container if not already present
if ! docker ps -a --format '{{.Names}}' | grep -q '^rexp$'; then
  docker run -d --init --entrypoint bash --workdir /data -v"${PWD}":/data --name rexp mdipenta/rexp -c 'sleep infinity'
fi

# Run the R analysis script inside the container to regenerate all tables, including Table 7
docker exec rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"

# Extract and format the reproduced Table 7 into /workspace/repro.txt
python - <<'PY'
import csv
from pathlib import Path

csv_path = Path("/workspace/artifact/ICSE2024-funcConstructs-Artifacts/results/Table-7-RQ1-reduce.csv")
rows = list(csv.reader(csv_path.open()))
if not rows:
    raise SystemExit("No data found in Table-7-RQ1-reduce.csv")

header, data = rows[0], rows[1:6]

terms = ["(Intercept)", "MainFactorProc", "Usage Freq.", "Approvals", "StudentTrue"]

lines = []
lines.append("**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**")
lines.append("")
lines.append("| Term | Estimate | Std.Error | z value | Pr(>|z|) |")
lines.append("|---|---:|---:|---:|---:|")

for term, row in zip(terms, data):
    est, se, zval, p = row
    lines.append(
        f"| {term} | {float(est):.2f} | {float(se):.2f} | {float(zval):.2f} | {float(p):.2f} |"
    )

Path("/workspace/repro.txt").write_text("\n".join(lines))
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
