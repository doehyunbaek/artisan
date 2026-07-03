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
docker run -d --init --entrypoint bash --name ppt4j zhiyuanpan/ppt4j -c 'sleep infinity'
docker exec ppt4j /bin/bash --noprofile --norc -c "python replicate_rq1.py" > /workspace/rq1_raw.txt
awk '
function fmt(x) {
  v = x * 100;
  if (int(v + 0.5) == v) {
    return sprintf("%d%%", v);
  } else {
    return sprintf("%.1f%%", v);
  }
}
BEGIN {
  d1_acc=d1_prec=d1_rec=d1_f1="";
  d2_acc=d2_prec=d2_rec=d2_f1="";
}
/^D1[[:space:]]/ {
  d1_acc  = fmt($2);
  d1_prec = fmt($3);
  d1_rec  = fmt($4);
  d1_f1   = fmt($5);
}
/^D2[[:space:]]/ {
  d2_acc  = fmt($2);
  d2_prec = fmt($3);
  d2_rec  = fmt($4);
  d2_f1   = fmt($5);
}
END {
  print "**Table 2: Test results on the dataset**";
  print "";
  print "| Test Suite |        | **Metrics** Acc. | Prec. | Recall |    F1 |";
  print "| ---------- | ------ | ---------------: | ----: | -----: | ----: |";
  printf "| PPT4J      | **D1** | %15s | %5s | %6s | %5s |\n", d1_acc, d1_prec, d1_rec, d1_f1;
  printf "|            | **D2** | %15s | %5s | %6s | %5s |\n", d2_acc, d2_prec, d2_rec, d2_f1;
}
' /workspace/rq1_raw.txt > /workspace/repro.txt
docker rm -f ppt4j >/dev/null 2>&1 || true
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
