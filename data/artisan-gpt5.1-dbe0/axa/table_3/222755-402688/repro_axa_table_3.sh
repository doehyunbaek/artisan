#!/usr/bin/bash
set -euo pipefail

# Section 1: Expected table with filled-in values
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    |          169 |          50 |               34 |               3 |
| False Positives    |            1 |           1 |                0 |               0 |
| Precision          |       99.7 % |      99.8 % |         100.0 % |        100.0 % |

EOTABLE

# Section 2: Artifact download (required by workflow)
artisan get https://zenodo.org/records/13374578

# Section 3: Reproduction commands

# Ensure a clean container, then load and start the artifact image.
docker rm -f axa-container >/dev/null 2>&1 || true
docker load -i axa-artifact-image.tar
docker run -d --init --name axa-container --entrypoint bash axaimage -c 'sleep infinity'

# Run the full precision/recall experiments inside the container.
# Allow non-zero exit codes so we can still parse the produced logs.
docker exec axa-container /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh > /tmp/precision_js.log 2>&1" || true
docker exec axa-container /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh > /tmp/precision_native.log 2>&1" || true

# --- Java/JS metrics ---
# OPAL (Only Java) from the "without TAJS" block
JS_OPAL=$(docker exec axa-container awk '
  /without TAJS/ && stage==0 { stage=1; next }
  stage==1 && /true positives:/ { fp=$7; fn=$10 }
  stage==1 && /total precision:/ {
      prec=$4; gsub("%","",prec);
      print fp, fn, prec;
      exit
  }
' /tmp/precision_js.log)

# AXA (Java + XL) from the "with TAJS" block
JS_AXA=$(docker exec axa-container awk '
  /with TAJS/ && stage==0 { stage=1; next }
  stage==1 && /true positives:/ { fp=$7; fn=$10 }
  stage==1 && /total precision:/ {
      prec=$4; gsub("%","",prec);
      print fp, fn, prec;
      exit
  }
' /tmp/precision_js.log)

read -r JS_FP_OPAL JS_FN_OPAL JS_PREC_OPAL <<< "$JS_OPAL"
read -r JS_FP_AXA  JS_FN_AXA  JS_PREC_AXA  <<< "$JS_AXA"

# --- Java/Native metrics ---
# OPAL (Only Java) from the "without TAJS" block
NATIVE_OPAL=$(docker exec axa-container awk '
  /without TAJS/ && stage==0 { stage=1; next }
  stage==1 && /true positives:/ { fp=$7; fn=$10 }
  stage==1 && /total precision:/ {
      prec=$4; gsub("%","",prec);
      print fp, fn, prec;
      exit
  }
' /tmp/precision_native.log)

# AXA (Java + XL) from the "with TAJS" block
NATIVE_AXA=$(docker exec axa-container awk '
  /with TAJS/ && stage==0 { stage=1; next }
  stage==1 && /true positives:/ { fp=$7; fn=$10 }
  stage==1 && /total precision:/ {
      prec=$4; gsub("%","",prec);
      print fp, fn, prec;
      exit
  }
' /tmp/precision_native.log)

read -r NATIVE_FP_OPAL NATIVE_FN_OPAL NATIVE_PREC_OPAL <<< "$NATIVE_OPAL"
read -r NATIVE_FP_AXA  NATIVE_FN_AXA  NATIVE_PREC_AXA  <<< "$NATIVE_AXA"

# Format precision values to one decimal place to match the paper style.
printf -v JS_PREC_OPAL_FMT "%.1f" "$JS_PREC_OPAL"
printf -v JS_PREC_AXA_FMT  "%.1f" "$JS_PREC_AXA"
printf -v NATIVE_PREC_OPAL_FMT "%.1f" "$NATIVE_PREC_OPAL"
printf -v NATIVE_PREC_AXA_FMT  "%.1f" "$NATIVE_PREC_AXA"

# Construct the reproduced Table 3 into /workspace/repro.txt.
cat > /workspace/repro.txt <<EOT
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    | ${JS_FN_OPAL} | ${JS_FN_AXA} | ${NATIVE_FN_OPAL} | ${NATIVE_FN_AXA} |
| False Positives    | ${JS_FP_OPAL} | ${JS_FP_AXA} | ${NATIVE_FP_OPAL} | ${NATIVE_FP_AXA} |
| Precision          | ${JS_PREC_OPAL_FMT} % | ${JS_PREC_AXA_FMT} % | ${NATIVE_PREC_OPAL_FMT} % | ${NATIVE_PREC_AXA_FMT} % |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
