#!/usr/bin/bash
set -euo pipefail

cd /workspace

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    |          169 |          50 |               34 |               3 |
| False Positives    |            1 |           1 |                0 |               0 |
| Precision          |      99.70 % |     99.79 % |        100.00 %  |       100.00 %  |
EOTABLE

# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578

# Section 3: Reproduction commands (populate from reviewed steps)

# Load the pre-built Docker image and (re)start a container
docker load -i axa-artifact-image.tar

docker rm -f axa-table3 || true
docker run -d --init --name axa-table3 --entrypoint bash axaimage -c 'sleep infinity'

# Run precision/recall experiments for Java/JS and Java/Native and capture logs
docker exec axa-table3 /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh" > /tmp/js_precision.log 2>&1
docker exec axa-table3 /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh" > /tmp/native_precision.log 2>&1

# Extract metrics from JS log
js_fp_opal=$(awk -F'|' '/\| False Positives/ {gsub(/ /,"",$3); print $3; exit}' /tmp/js_precision.log)
js_fp_axa=$(awk -F'|' '/\| False Positives/ {gsub(/ /,"",$4); print $4; exit}' /tmp/js_precision.log)

js_fn_opal=$(awk -F'|' '/\| False Negatives/ {gsub(/ /,"",$3); print $3; exit}' /tmp/js_precision.log)
js_fn_axa=$(awk -F'|' '/\| False Negatives/ {gsub(/ /,"",$4); print $4; exit}' /tmp/js_precision.log)

js_prec_opal=$(awk -F'|' '/\| Precision/ {gsub(/ /,"",$3); print $3; exit}' /tmp/js_precision.log)
js_prec_axa=$(awk -F'|' '/\| Precision/ {gsub(/ /,"",$4); print $4; exit}' /tmp/js_precision.log)

# Extract metrics from Native log
nat_fp_opal=$(awk -F'|' '/\| False Positives/ {gsub(/ /,"",$3); print $3; exit}' /tmp/native_precision.log)
nat_fp_axa=$(awk -F'|' '/\| False Positives/ {gsub(/ /,"",$4); print $4; exit}' /tmp/native_precision.log)

nat_fn_opal=$(awk -F'|' '/\| False Negatives/ {gsub(/ /,"",$3); print $3; exit}' /tmp/native_precision.log)
nat_fn_axa=$(awk -F'|' '/\| False Negatives/ {gsub(/ /,"",$4); print $4; exit}' /tmp/native_precision.log)

nat_prec_opal=$(awk -F'|' '/\| Precision/ {gsub(/ /,"",$3); print $3; exit}' /tmp/native_precision.log)
nat_prec_axa=$(awk -F'|' '/\| Precision/ {gsub(/ /,"",$4); print $4; exit}' /tmp/native_precision.log)

# Write the reproduced table
cat > /workspace/repro.txt <<EOTABLE
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    | ${js_fn_opal} | ${js_fn_axa} | ${nat_fn_opal} | ${nat_fn_axa} |
| False Positives    | ${js_fp_opal} | ${js_fp_axa} | ${nat_fp_opal} | ${nat_fp_axa} |
| Precision          | ${js_prec_opal} % | ${js_prec_axa} % | ${nat_prec_opal} % | ${nat_prec_axa} % |
EOTABLE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
