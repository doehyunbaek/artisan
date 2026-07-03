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
artisan get https://github.com/pan2013e/ppt4j
# Section 3: Reproduction commands
docker inspect --format='{{.State.Running}}' ppt4j_container >/dev/null 2>&1 || docker run -d --init --entrypoint bash --name ppt4j_container zhiyuanpan/ppt4j -c 'sleep infinity'
docker exec ppt4j_container /bin/bash --noprofile --norc -c "cd /ppt4j && python replicate_rq1.py" > /workspace/repro.txt 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
