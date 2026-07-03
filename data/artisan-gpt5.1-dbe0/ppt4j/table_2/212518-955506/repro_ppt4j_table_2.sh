#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Test results on the dataset**

| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |
| ---------- | ------ | ---------------: | ----: | -----: | ----: |
| PPT4J      | **D1** |             ???% |  ???% |   ???% |  ???% |
|            | **D2** |            ??.?% |  ???% |  ??.?% | ??.?% |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/pan2013e/ppt4j
# Section 3: Reproduction commands (populate from reviewed steps)
docker pull zhiyuanpan/ppt4j
docker rm -f ppt4j-container >/dev/null 2>&1 || true
docker run -d --init --name ppt4j-container --entrypoint bash zhiyuanpan/ppt4j -c 'sleep infinity'
docker exec ppt4j-container /bin/bash --noprofile --norc -c "python replicate_rq1.py" > /tmp/ppt4j_rq1.out
python - <<'PY'
import pathlib

# Read replicate_rq1.py output captured from the container
text = pathlib.Path("/tmp/ppt4j_rq1.out").read_text().strip().splitlines()
# Last two lines summarize metrics for D1 and D2
d1_line = text[-2].split()
d2_line = text[-1].split()
d1 = [float(x) for x in d1_line[1:5]]
d2 = [float(x) for x in d2_line[1:5]]

def fmt(x: float) -> str:
    return f"{x*100:.1f}%"

table = f"""**Table 2: Test results on the dataset**

| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |
| ---------- | ------ | ---------------: | ----: | -----: | ----: |
| PPT4J      | **D1** | {fmt(d1[0])} |  {fmt(d1[1])} |   {fmt(d1[2])} |  {fmt(d1[3])} |
|            | **D2** | {fmt(d2[0])} |  {fmt(d2[1])} |  {fmt(d2[2])} | {fmt(d2[3])} |
"""
pathlib.Path("/workspace/repro.txt").write_text(table)
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
