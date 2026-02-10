#!/usr/bin/bash
git clone https://github.com/pan2013e/ppt4j || true

docker rm -f ppt4j_rep >/dev/null 2>&1 || true
docker pull zhiyuanpan/ppt4j >/dev/null
docker run -d --init --name ppt4j_rep zhiyuanpan/ppt4j tail -f /dev/null >/dev/null
docker exec ppt4j_rep bash -lc 'python replicate_rq1.py' > /workspace/repro.txt 2>&1
docker stop ppt4j_rep >/dev/null || true
docker rm ppt4j_rep >/dev/null || true

echo '<artisan_submit>'
python3 - <<'PY'
import re

t = open("/workspace/repro.txt", "r", encoding="utf-8", errors="replace").read()

rows = {}
for m in re.finditer(
    r'(?m)^(D[12])\s+([0-9]*\.[0-9]+)\s+([0-9]*\.[0-9]+)\s+([0-9]*\.[0-9]+)\s+([0-9]*\.[0-9]+)\s*$',
    t,
):
    d, acc, prec, rec, f1 = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    rows[d] = tuple(float(x) for x in (acc, prec, rec, f1))

if "D1" not in rows or "D2" not in rows:
    raise SystemExit("Could not find D1/D2 metric rows in /workspace/repro.txt")

def pct(x: float) -> str:
    v = x * 100.0
    if abs(v - round(v)) < 1e-9:
        return f"{int(round(v))}%"
    return f"{v:.1f}%"

print("**Table 2: Test results on the dataset**\n")
print("| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |")
print("| ---------- | ------ | ---------------: | ----: | -----: | ----: |")

acc, prec, rec, f1 = rows["D1"]
print(f"| PPT4J      | **D1** | {pct(acc):>16} | {pct(prec):>5} | {pct(rec):>6} | {pct(f1):>5} |")

acc, prec, rec, f1 = rows["D2"]
print(f"|            | **D2** | {pct(acc):>16} | {pct(prec):>5} | {pct(rec):>6} | {pct(f1):>5} |")

print()  # newline at EOF
PY
echo '</artisan_submit>'
