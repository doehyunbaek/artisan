#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    |          ??? |          ?? |               ?? |               ? |
| False Positives    |            ? |           ? |                ? |               ? |
| Precision          |       ??.? % |      ??.? % |          ???.? % |         ???.? % |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/13374578
# Section 3: Reproduction commands
# Load the docker image
docker load -i axa-artifact-image.tar
# Start container
docker run -d --init -v /workspace:/workspace --name axa_container_table3 --entrypoint bash axaimage -c 'sleep infinity'
# Run JavaScript precision/recall and capture output
docker exec axa_container_table3 /bin/bash --noprofile --norc -c "cd /runner && ./precisionRecallJS.sh 2>&1" > /workspace/js_output_full.txt 2>&1
# Run Native precision/recall and capture output
docker exec axa_container_table3 /bin/bash --noprofile --norc -c "cd /runner && ./precisionRecallNative.sh 2>&1" > /workspace/native_output_full.txt 2>&1
# Clean up container
docker stop axa_container_table3 && docker rm axa_container_table3
# Extract values from output files using more precise patterns
# For JavaScript output - extract table rows
js_fp_line=$(grep -A 10 "Results of Points-To Analysis" /workspace/js_output_full.txt | grep "False Positives" | head -1)
js_fn_line=$(grep -A 10 "Results of Points-To Analysis" /workspace/js_output_full.txt | grep "False Negatives" | head -1)
js_prec_line=$(grep -A 10 "Results of Points-To Analysis" /workspace/js_output_full.txt | grep "| Precision" | head -1)
# Extract numbers using awk
js_fp_opal=$(echo "$js_fp_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$3); print $3}')
js_fp_axa=$(echo "$js_fp_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$4); print $4}')
js_fn_opal=$(echo "$js_fn_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$3); print $3}')
js_fn_axa=$(echo "$js_fn_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$4); print $4}')
js_prec_opal=$(echo "$js_prec_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$3); print $3}')
js_prec_axa=$(echo "$js_prec_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$4); print $4}')
# For Native output
native_fp_line=$(grep -A 10 "Results of Points-To Analysis" /workspace/native_output_full.txt | grep "False Positives" | head -1)
native_fn_line=$(grep -A 10 "Results of Points-To Analysis" /workspace/native_output_full.txt | grep "False Negatives" | head -1)
native_prec_line=$(grep -A 10 "Results of Points-To Analysis" /workspace/native_output_full.txt | grep "| Precision" | head -1)
# Extract numbers using awk
native_fp_opal=$(echo "$native_fp_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$3); print $3}')
native_fp_axa=$(echo "$native_fp_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$4); print $4}')
native_fn_opal=$(echo "$native_fn_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$3); print $3}')
native_fn_axa=$(echo "$native_fn_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$4); print $4}')
native_prec_opal=$(echo "$native_prec_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$3); print $3}')
native_prec_axa=$(echo "$native_prec_line" | awk -F'|' '{gsub(/[^0-9.]/,"",$4); print $4}')
# Create reproduction table
cat > /workspace/repro.txt <<'REPRO'
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    |          REPLACE_JS_FN_OPAL |          REPLACE_JS_FN_AXA |               REPLACE_NATIVE_FN_OPAL |               REPLACE_NATIVE_FN_AXA |
| False Positives    |            REPLACE_JS_FP_OPAL |           REPLACE_JS_FP_AXA |                REPLACE_NATIVE_FP_OPAL |               REPLACE_NATIVE_FP_AXA |
| Precision          |       REPLACE_JS_PREC_OPAL % |      REPLACE_JS_PREC_AXA % |          REPLACE_NATIVE_PREC_OPAL % |         REPLACE_NATIVE_PREC_AXA % |
REPRO
# Replace placeholders with extracted values
sed -i "s/REPLACE_JS_FN_OPAL/$js_fn_opal/g" /workspace/repro.txt
sed -i "s/REPLACE_JS_FN_AXA/$js_fn_axa/g" /workspace/repro.txt
sed -i "s/REPLACE_NATIVE_FN_OPAL/$native_fn_opal/g" /workspace/repro.txt
sed -i "s/REPLACE_NATIVE_FN_AXA/$native_fn_axa/g" /workspace/repro.txt
sed -i "s/REPLACE_JS_FP_OPAL/$js_fp_opal/g" /workspace/repro.txt
sed -i "s/REPLACE_JS_FP_AXA/$js_fp_axa/g" /workspace/repro.txt
sed -i "s/REPLACE_NATIVE_FP_OPAL/$native_fp_opal/g" /workspace/repro.txt
sed -i "s/REPLACE_NATIVE_FP_AXA/$native_fp_axa/g" /workspace/repro.txt
sed -i "s/REPLACE_JS_PREC_OPAL/$js_prec_opal/g" /workspace/repro.txt
sed -i "s/REPLACE_JS_PREC_AXA/$js_prec_axa/g" /workspace/repro.txt
sed -i "s/REPLACE_NATIVE_PREC_OPAL/$native_prec_opal/g" /workspace/repro.txt
sed -i "s/REPLACE_NATIVE_PREC_AXA/$native_prec_axa/g" /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
