#!/usr/bin/bash
set -euo pipefail

curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 \
  -o ICSE2024-funcConstructs-Artifacts.zip \
  https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content

unzip -o ICSE2024-funcConstructs-Artifacts.zip -d ICSE2024-funcConstructs-Artifacts

docker pull mdipenta/rexp:latest
docker rm -f func_rexp >/dev/null 2>&1 || true

docker run -d --init --entrypoint bash --name func_rexp \
  -v /workspace/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts:/data \
  mdipenta/rexp:latest -c 'sleep infinity'

docker exec func_rexp /bin/bash --noprofile --norc -c "cd /data && R --no-save < FuncConstructs-Statistics.r"
docker cp func_rexp:/data/results /workspace/
docker stop func_rexp >/dev/null
docker rm func_rexp >/dev/null

cat /workspace/results/Table-7-RQ1-reduce.csv > /workspace/repro.txt

echo '<artisan_submit>'
python3 - <<'PY'
import csv

r = list(csv.reader(open("/workspace/repro.txt", encoding="utf-8", errors="replace")))
vals = [list(map(float, row)) for row in r[1:] if row]
terms = ["(Intercept)","MainFactorProc","Usage Freq.","Approvals","StudentTrue"]

def fmt(x: float) -> str:
    y = round(x, 2)   # avoids printing -0.00 for tiny negatives
    if y == 0:
        y = 0.0
    return f"{y:.2f}"

print("**Table 7: RQ1: Logistic regression relating the use of reduce with the correctness of the change task (AIC=118)**\n")
print("| Term | Estimate | Std.Error | z value | Pr(>\\|z\\|) |")
print("|---|---:|---:|---:|---:|")
for term, (est, se, z, p) in zip(terms, vals):
    print(f"| {term} | {fmt(est)} | {fmt(se)} | {fmt(z)} | {fmt(p)} |")

print()  # ensure trailing newline at EOF
PY
echo '</artisan_submit>'
