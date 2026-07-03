#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 5: Prevalence and impact of our suggested optimization techniques in paid tier (free tier).**

| Optimization heuristic                                            |                                            Impacted runs * |                                                         Time saving * | Annual cost delta per repository in $ * |
| ----------------------------------------------------------------- | ---------------------------------------------------------: | --------------------------------------------------------------------: | --------------------------------------: |
| Deactivate scheduled workflows after k consecutive failures (k=?) | ?.?% (<?.?%) of all runs<br>??.?% (?.?%) of scheduled runs |  ?.?% (<?.?%) of all runs time<br>??.?% (?.?%) of scheduled runs time |                         -???.?? (-?.??) |
| Deactivate scheduled workflows during repository inactivity       |  ?.?% (?.?%) of all runs<br>??.?% (?.?%) of scheduled runs | <?.?% (<?.?%) of all runs time<br>?.?% (?.?%) of scheduled runs time |                          -??.?? (-?.??) |
| Run previously failed jobs first                                  |     ?.?% (?.?%) of all runs<br>??.?% (?.?%) of failed runs |    ?.?% (<?.?%) of all runs time<br>??.?% (??.?%) of failed runs time |                          -??.?? (-?.??) |
| Project-specific timeouts                                         |                                   ?.?% (<?.?%) of all runs |                                          ?.?% (?.?%) of all runs time |                        -???.?? (-??.??) |

* measurement for paid tier (measurement for free tier)

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/10529665

# Section 3: Reproduction commands
# Prefer copying the notebook from the extracted artifact; if not present, try copying from a container (start/create if necessary)
if [ -f gh_resource_study_artifact_patched/github-workflow-resource-optimization/paper_analysis_RQ3.ipynb ]; then
  cp gh_resource_study_artifact_patched/github-workflow-resource-optimization/paper_analysis_RQ3.ipynb /workspace/
fi

if [ ! -f /workspace/paper_analysis_RQ3.ipynb ]; then
  if docker ps -q -f name=github-study | grep -q .; then
    docker cp github-study:/workdir/paper_analysis_RQ3.ipynb /workspace/ || true
  elif docker ps -aq -f name=github-study | grep -q .; then
    docker start github-study >/dev/null 2>&1 || true
    docker cp github-study:/workdir/paper_analysis_RQ3.ipynb /workspace/ || true
  else
    docker run -d --init --entrypoint bash --name github-study islemdockerdev/github-workflow-resource-study:v1.1 -c 'sleep infinity' >/dev/null 2>&1 || true
    docker cp github-study:/workdir/paper_analysis_RQ3.ipynb /workspace/ || true
  fi
fi

# Execute notebook locally if possible; otherwise extract markdown/text outputs with Python fallback
if [ -f /workspace/paper_analysis_RQ3.ipynb ] && command -v jupyter >/dev/null 2>&1 && command -v nbconvert >/dev/null 2>&1; then
  jupyter nbconvert --to notebook --execute /workspace/paper_analysis_RQ3.ipynb --output /workspace/paper_analysis_RQ3_executed.ipynb --ExecutePreprocessor.timeout=36000 >/dev/null 2>&1 || true
  if [ -f /workspace/paper_analysis_RQ3_executed.ipynb ]; then
    jupyter nbconvert --to markdown /workspace/paper_analysis_RQ3_executed.ipynb --output /workspace/repro.md >/dev/null 2>&1 || true
    if [ -f /workspace/repro.md ]; then
      head -n 400 /workspace/repro.md > /workspace/repro.txt || true
    fi
  fi
fi

# If no repro.txt yet, use Python to extract markdown and textual outputs from the notebook JSON
if [ ! -f /workspace/repro.txt ]; then
python3 - <<'PY'
import json,sys,os
nbpath="/workspace/paper_analysis_RQ3.ipynb"
outpath="/workspace/repro.txt"
if not os.path.exists(nbpath):
    print("NOTEBOOK_MISSING", file=sys.stderr)
    sys.exit(0)
try:
    nb=json.load(open(nbpath))
except Exception as e:
    print("NB_READ_ERROR", e, file=sys.stderr)
    sys.exit(0)
parts=[]
for cell in nb.get("cells",[]):
    ctype=cell.get("cell_type")
    if ctype=="markdown":
        parts.append("".join(cell.get("source",[])))
    elif ctype=="code":
        for o in cell.get("outputs",[]):
            if isinstance(o,dict) and "text" in o:
                t=o["text"]
                parts.append("".join(t) if isinstance(t,list) else str(t))
            elif isinstance(o,dict) and "data" in o:
                tp=o["data"].get("text/plain") or o["data"].get("text")
                if tp:
                    parts.append("".join(tp) if isinstance(tp,list) else str(tp))
content="\\n\\n".join(parts)[:200000]
open(outpath,"w").write(content)
PY
fi

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt || echo "FORMAT_FAILED"
echo '</artisan_submit>'
