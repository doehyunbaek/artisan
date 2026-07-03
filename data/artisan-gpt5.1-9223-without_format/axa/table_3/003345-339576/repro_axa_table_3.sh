#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    |          169 |          50 |               34 |               3 |
| False Positives    |            1 |           1 |                0 |               0 |
| Precision          |       99.7 % |      99.8 % |          100.0 % |         100.0 % |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578

# Section 3: Reproduction commands (populate from reviewed steps)
cd /workspace

# Load the provided Docker image and start a fresh container
docker load -i axa-artifact-image.tar
docker rm -f axa-table3-container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name axa-table3-container axaimage -c 'sleep infinity'

# Run precision/recall experiments for Java/JS and Java/Native and capture logs
docker exec axa-table3-container /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh" > /workspace/js_precision_recall.log 2>&1
docker exec axa-table3-container /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh" > /workspace/native_precision_recall.log 2>&1

# Parse Java/JS results (Only Java = OPAL, Java + XL = AXA)
JS_VALUES=$(awk -F'|' '
  /False Negatives/ {fn_opal=$3+0; fn_axa=$4+0}
  / Precision/ && !/Recall/ {prec_opal=$3+0; prec_axa=$4+0}
  END {printf "%d %d %.2f %.2f\n", fn_opal, fn_axa, prec_opal, prec_axa}
' /workspace/js_precision_recall.log)

JS_FP_VALUES=$(awk -F'|' '
  /False Positives/ {fp_opal=$3+0; fp_axa=$4+0}
  END {printf "%d %d\n", fp_opal, fp_axa}
' /workspace/js_precision_recall.log)

read JS_FN_OPAL JS_FN_AXA JS_PREC_OPAL JS_PREC_AXA <<< "$JS_VALUES"
read JS_FP_OPAL JS_FP_AXA <<< "$JS_FP_VALUES"

# Parse Java/Native results
NATIVE_VALUES=$(awk -F'|' '
  /False Negatives/ {fn_opal=$3+0; fn_axa=$4+0}
  / Precision/ && !/Recall/ {prec_opal=$3+0; prec_axa=$4+0}
  END {printf "%d %d %.2f %.2f\n", fn_opal, fn_axa, prec_opal, prec_axa}
' /workspace/native_precision_recall.log)

NAT_FP_VALUES=$(awk -F'|' '
  /False Positives/ {fp_opal=$3+0; fp_axa=$4+0}
  END {printf "%d %d\n", fp_opal, fp_axa}
' /workspace/native_precision_recall.log)

read NAT_FN_OPAL NAT_FN_AXA NAT_PREC_OPAL NAT_PREC_AXA <<< "$NATIVE_VALUES"
read NAT_FP_OPAL NAT_FP_AXA <<< "$NAT_FP_VALUES"

# Write reproduced Table 3 to /workspace/repro.txt
cat > /workspace/repro.txt <<REPRO
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    | ${JS_FN_OPAL} | ${JS_FN_AXA} | ${NAT_FN_OPAL} | ${NAT_FN_AXA} |
| False Positives    | ${JS_FP_OPAL} | ${JS_FP_AXA} | ${NAT_FP_OPAL} | ${NAT_FP_AXA} |
| Precision          | $(printf "%.1f %%" "$JS_PREC_OPAL") | $(printf "%.1f %%" "$JS_PREC_AXA") | $(printf "%.1f %%" "$NAT_PREC_OPAL") | $(printf "%.1f %%" "$NAT_PREC_AXA") |
REPRO

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
