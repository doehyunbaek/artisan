#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Test results on the dataset**

| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |
| ---------- | ------ | ---------------: | ----: | -----: | ----: |
| PPT4J      | **D1** |             100% |  100% |   100% |  100% |
|            | **D2** |            98.5% |  100% |  97.0% | 98.5% |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -d ppt4j ]; then
  git clone https://github.com/pan2013e/ppt4j.git
fi
# Section 3: Reproduction commands (populate from reviewed steps)
docker pull zhiyuanpan/ppt4j
CID=$(docker run -d --init --entrypoint bash zhiyuanpan/ppt4j -c 'sleep infinity')
docker exec "$CID" /bin/bash --noprofile --norc -c "cd /ppt4j && python replicate_rq1.py" > /workspace/repro_raw.txt
docker rm -f "$CID" >/dev/null 2>&1 || true

python - << 'PY'
import pathlib

raw = pathlib.Path("/workspace/repro_raw.txt").read_text().splitlines()
metrics = {}
for line in raw:
    if line.startswith("D1") or line.startswith("D2"):
        parts = line.split()
        label = parts[0]
        acc, prec, rec, f1 = map(float, parts[1:])
        metrics[label] = (acc, prec, rec, f1)


def fmt_pct(x: float) -> str:
    pct = x * 100.0
    if abs(pct - round(pct)) < 1e-6:
        return f"{int(round(pct))}%"
    else:
        return f"{pct:.1f}%"


d1_acc, d1_prec, d1_rec, d1_f1 = [fmt_pct(v) for v in metrics["D1"]]
d2_acc, d2_prec, d2_rec, d2_f1 = [fmt_pct(v) for v in metrics["D2"]]

lines = []
lines.append("**Table 2: Test results on the dataset**")
lines.append("")
lines.append("| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |")
lines.append("| ---------- | ------ | ---------------: | ----: | -----: | ----: |")
lines.append(f"| PPT4J      | **D1** |             {d1_acc} |  {d1_prec} |   {d1_rec} |  {d1_f1} |")
lines.append(f"|            | **D2** |            {d2_acc} |  {d2_prec} |  {d2_rec} | {d2_f1} |")

pathlib.Path("/workspace/repro.txt").write_text("\n".join(lines) + "\n")
PY

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
