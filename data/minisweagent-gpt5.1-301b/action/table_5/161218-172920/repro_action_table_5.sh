#!/usr/bin/bash
set -e
cd /workspace
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=3) | 4.5% (<0.1%) of all runs<br>17.2% (1.0%) of scheduled runs |  3.2% (<0.1%) of all runs time<br>21.3% (4.9%) of scheduled runs time |                         -125.72 (-1.55) |
| Deactivate scheduled workflows during repository inactivity       |  4.5% (0.6%) of all runs<br>17.1% (1.4%) of scheduled runs | <0.1% (<0.1%) of all runs time<br>0.1% (0.1%) of scheduled runs time |                          -99.78 (-3.81) |
| Run previously failed jobs first                                  |     1.0% (0.8%) of all runs<br>29.5% (7.7%) of failed runs |    1.1% (<0.1%) of all runs time<br>31.6% (45.3%) of failed runs time |                          -17.89 (-0.77) |
| Project-specific timeouts                                         |                                   0.5% (<0.1%) of all runs |                                          3.5% (2.2%) of all runs time |                        -173.71 (-47.49) |

* measurement for paid tier (measurement for free tier)

EOTABLE
# Section 2: Artifact download
if [ ! -f /workspace/gh_resource_study_artifact_patched.zip ]; then
  curl -L -o /workspace/gh_resource_study_artifact_patched.zip 'https://zenodo.org/api/records/10529665/files/gh_resource_study_artifact_patched.zip/content'
fi
# Section 3: Reproduction commands (populate from reviewed steps)
docker pull islemdockerdev/github-workflow-resource-study:v1.1
docker rm -f github-study >/dev/null 2>&1 || true
docker run -d --init --name github-study --entrypoint bash islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity'
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && pip install -q jupyterlab"
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && pip install -q ."
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && jupyter nbconvert --to script paper_analysis_RQ3.ipynb"
docker exec github-study /bin/bash --noprofile --norc -c "cd /workdir && python paper_analysis_RQ3.py" > /workspace/RQ3_output.txt
python - <<'PY'
import pathlib

rq3_path = pathlib.Path("/workspace/RQ3_output.txt")
lines = rq3_path.read_text().splitlines()

start = None
for i, line in enumerate(lines):
    if line.strip().startswith("Optimization heuristic"):
        start = i
        break

if start is None:
    raise SystemExit("Optimization table header not found in RQ3_output.txt")

table_lines = lines[start:]

def is_sep(l):
    s = l.strip()
    return len(s) >= 10 and set(s) == {"-"}

header = table_lines[0]
data_lines = table_lines[2:]  # skip header and first separator

blocks = []
current = []
for l in data_lines:
    if is_sep(l):
        if current:
            blocks.append(current)
            current = []
        continue
    current.append(l)
if current:
    blocks.append(current)

# keep first four optimization blocks
blocks = blocks[:4]

def split_cols(line):
    line = line.rstrip("\n")
    if len(line) < 160:
        line = line + " " * (160 - len(line))
    return [
        line[0:40].rstrip(),
        line[40:80].rstrip(),
        line[80:120].rstrip(),
        line[120:160].rstrip(),
    ]

rows = []
for block in blocks:
    if len(block) == 1:
        block.append(" " * 160)
    line1, line2 = block[0], block[1]
    c1a, c2a, c3a, c4a = split_cols(line1)
    c1b, c2b, c3b, c4b = split_cols(line2)
    name = (c1a + " " + c1b).strip()
    impacted = c2a
    if c2b:
        impacted += "<br>" + c2b
    time = c3a
    if c3b:
        time += "<br>" + c3b
    cost = c4a
    rows.append((name, impacted, time, cost))

out_lines = []
out_lines.append("**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**")
out_lines.append("")
out_lines.append("| Optimization heuristic | Impacted runs * | Time saving * | Annual cost delta per repository in $ * |")
out_lines.append("| ---------------------- | --------------: | ------------: | --------------------------------------: |")
for name, impacted, time, cost in rows:
    out_lines.append(f"| {name} | {impacted} | {time} | {cost} |")
out_lines.append("")
out_lines.append("* measurement for paid tier (measurement for free tier)")
pathlib.Path("/workspace/repro.txt").write_text("\n".join(out_lines))
PY
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
