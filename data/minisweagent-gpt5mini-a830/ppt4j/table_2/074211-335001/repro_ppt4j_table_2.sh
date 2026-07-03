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
# Clone the artifact into the workspace (if already present, ignore errors)
git clone https://github.com/pan2013e/ppt4j /workspace/ppt4j || true

# Section 3: Reproduction commands (populate from reviewed steps)
# Try to pull the recommended images (complete preferred, fallback to default/minimal)
docker pull zhiyuanpan/ppt4j:complete-latest || docker pull zhiyuanpan/ppt4j || docker pull zhiyuanpan/ppt4j:minimal-latest || true

# Run the container detached with /workspace mounted so outputs are saved on the host.
# Use the required replacement for interactive runs.
docker run -d --init --entrypoint bash -v /workspace:/workspace --name ppt4j_rep zhiyuanpan/ppt4j:complete-latest -c 'sleep infinity' || \
docker run -d --init --entrypoint bash -v /workspace:/workspace --name ppt4j_rep zhiyuanpan/ppt4j -c 'sleep infinity' || true

# Execute tests inside the running container. Try to locate the project directory inside the container and run the test command(s).
# Capture stdout/stderr to /workspace/repro.txt (on the host via the mounted volume).
docker exec ppt4j_rep /bin/bash --noprofile --norc -c "\
  (cd /home/ppt4j 2>/dev/null || cd /root/ppt4j 2>/dev/null || cd /ppt4j 2>/dev/null || cd /workspace/ppt4j 2>/dev/null || true) && \
  (python -m scripts.test all > /workspace/repro.txt 2>&1 || python replicate_rq1.py > /workspace/repro.txt 2>&1 || echo 'No recognized test command succeeded.' > /workspace/repro.txt) || true"

# Section 4: Formatting and submission block
echo '<artisan_submit>'
if [ -f /workspace/repro.txt ]; then
  sed -n '1,200p' /workspace/repro.txt
else
  echo 'No reproduction output found at /workspace/repro.txt'
fi
echo '</artisan_submit>'
