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
docker run -d --init --entrypoint bash --name ppt4j_table2 zhiyuanpan/ppt4j -c 'sleep infinity'
docker exec ppt4j_table2 /bin/bash --noprofile --norc -c "python replicate_rq1.py" > /workspace/repro_full.txt
tail -n 3 /workspace/repro_full.txt > /workspace/repro.txt
docker rm -f ppt4j_table2
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
