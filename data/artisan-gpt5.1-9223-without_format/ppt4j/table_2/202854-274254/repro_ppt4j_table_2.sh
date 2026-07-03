#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Test results on the dataset**

| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |
| ---------- | ------ | ---------------: | ----: | -----: | ----: |
| PPT4J      | **D1** |            100% |  100% |   100% |  100% |
|            | **D2** |           98.5% |  100% |   97.0% | 98.5% |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/pan2013e/ppt4j
# Section 3: Reproduction commands
docker pull zhiyuanpan/ppt4j
docker rm -f ppt4j >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name ppt4j zhiyuanpan/ppt4j -c 'sleep infinity'
# Run the RQ1 replication script and keep only the D1/D2 metric summary lines.
docker exec ppt4j /bin/bash --noprofile --norc -c "python replicate_rq1.py | grep '^D[12]'" > /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
awk '
BEGIN {
  print "**Table 2: Test results on the dataset**\n"
  print "| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |"
  print "| ---------- | ------ | ---------------: | ----: | -----: | ----: |"
}
$1=="D1" {
  # D1: all metrics shown as whole percentages
  printf("| PPT4J      | **D1** | %15.0f%% | %4.0f%% | %6.0f%% | %5.0f%% |\n", $2*100, $3*100, $4*100, $5*100)
}
$1=="D2" {
  # D2: Acc/Recall/F1 with one decimal, but Prec as an integer percentage
  printf("|            | **D2** | %15.1f%% | %4.0f%% | %6.1f%% | %5.1f%% |\n", $2*100, $3*100, $4*100, $5*100)
}
' /workspace/repro.txt
echo '</artisan_submit>'
