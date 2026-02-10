#!/usr/bin/bash
curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 30 -o ICSE2024-funcConstructs-Artifacts.zip https://zenodo.org/api/records/10554377/files/ICSE2024-funcConstructs-Artifacts.zip/content
unzip ICSE2024-funcConstructs-Artifacts.zip -d  ICSE2024-funcConstructs-Artifacts
docker pull mdipenta/rexp:latest
docker run -d --init --entrypoint bash --name shell mdipenta/rexp:latest -c 'sleep infinity'
docker rm -f shell && docker run -d --init -v /workspace:/data --entrypoint bash --name shell mdipenta/rexp:latest -c 'sleep infinity'
docker exec shell /bin/bash --noprofile --norc -c "cd /data/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts && R --no-save < FuncConstructs-Statistics.r"
# Capture the specific Table 5 (MRF model summary) output into /workspace/repro.txt
docker exec shell /bin/bash --noprofile --norc -c "cat /data/ICSE2024-funcConstructs-Artifacts/ICSE2024-funcConstructs-Artifacts/results/Table-5-RQ1-mrf.txt" > /workspace/repro.txt

echo '<artisan_submit>'
python3 - <<'PY'
import re, math

t=open("/workspace/repro.txt",encoding="utf-8",errors="replace").read()

aic,bic,ll,dev,df = map(float, re.search(r"(?m)^\s*(\d+\.\d)\s+(\d+\.\d)\s+(-?\d+\.\d)\s+(\d+\.\d)\s+(\d+)\s*$", t).groups())
mn,q1,med,q3,mx = map(float, re.search(r"(?m)^\s*Min\s+1Q\s+Median\s+3Q\s+Max\s*\n\s*([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s*$", t).groups())
var,sd = re.search(r"(?m)^\s*User\s+\(Intercept\)\s+([0-9.]+)\s+([0-9.]+)\s*$", t).groups()
nobs,ngrp = map(int, re.search(r"Number of obs:\s*(\d+),\s*groups:\s*User,\s*(\d+)", t).groups())

block = re.search(r"(?s)Fixed effects:\s*\n.*?\n(.*?)(?:\n\s*\n|\Z)", t).group(1)
rows={}
for l in block.splitlines():
    m=re.match(r"^\s*(\S+)\s+([-0-9.eE]+)\s+([-0-9.eE]+)\s+([-0-9.eE]+)\s+([-0-9.eE]+)\s*$", l)
    if m: rows[m.group(1)]=tuple(map(float,m.groups()[1:]))

order=[("(Intercept)","(Intercept)"),("MainFactorp","MainFactorProc"),("UsageFrequency","Usage Freq."),("Approvals","Approvals"),("StudentTRUE","StudentTrue")]

print("**Table 5: RQ1: Mixed-effect logistic regression relating the use of MRF with the correctness of the change task**\n")
print("|                  |        |")
print("| ---------------- | ------ |")
print(f"| **AIC**          | {aic:.1f}  |")
print(f"| **BIC**          | {bic:.1f}  |")
print(f"| **logLik**       | {ll:.1f} |")
print(f"| **deviance**     | {dev:.1f}  |")
print(f"| **df.residuals** | {int(df):d}    |\n")
print(f"**Scaled residuals:** Min {mn:.2f}, 1Q {q1:.2f}, Median {med:.2f}, 3Q {q3:.2f}, Max {mx:.2f}\n")
print(f"**Random effects (Groups)** — User (Intercept): Variance {var}, Std.Dev. {sd}; Number of obs: {nobs}, groups: User, {ngrp}\n")
print("**Fixed effects**\n")
print("| Term | OR | Estimate | Std.Error | z value | Pr(>\\|z\\|) |")
print("|---|---:|---:|---:|---:|---:|")
for src,disp in order:
    est,se,z,p = rows[src]
    print(f"| {disp} | {math.exp(est):.2f} | {est:.2f} | {se:.2f} | {z:.2f} | {p:.2f} |")
PY
echo '</artisan_submit>'
