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
set -e

# Download artifact archive and Docker image
curl -L 'https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1' -o /workspace/axa-artifact.zip
curl -L 'https://zenodo.org/records/13374578/files/axa-artifact-image.tar?download=1' -o /workspace/axa-artifact-image.tar

# Section 3: Reproduction commands (populate from reviewed steps)

# Prepare artifact directory and unpack
mkdir -p /workspace/axa-artifact
unzip -o -d /workspace/axa-artifact /workspace/axa-artifact.zip

# Load Docker image and start container
docker load -i /workspace/axa-artifact-image.tar
docker rm -f axa_container 2>/dev/null || true
docker run -d --init --name axa_container --entrypoint bash axaimage -c 'sleep infinity'

# Run precision/recall experiments inside container, capturing logs
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh > /tmp/precision_js.log 2>&1"
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh > /tmp/precision_native.log 2>&1"

# Copy logs to host workspace for parsing
docker cp axa_container:/tmp/precision_js.log /workspace/precision_js.log
docker cp axa_container:/tmp/precision_native.log /workspace/precision_native.log

# Extract metrics for Table 3 from JS log
js_fp_opal=$(awk '/Results of Points-To Analysis/{flag=1} flag && /\| False Positives/{print $6; exit}' /workspace/precision_js.log)
js_fp_axa=$(awk  '/Results of Points-To Analysis/{flag=1} flag && /\| False Positives/{print $8; exit}' /workspace/precision_js.log)
js_fn_opal=$(awk '/Results of Points-To Analysis/{flag=1} flag && /\| False Negatives/{print $6; exit}' /workspace/precision_js.log)
js_fn_axa=$(awk  '/Results of Points-To Analysis/{flag=1} flag && /\| False Negatives/{print $8; exit}' /workspace/precision_js.log)
js_prec_opal=$(awk '/Results of Points-To Analysis/{flag=1} flag && /\| Precision/{printf "%.1f", $6; exit}' /workspace/precision_js.log)
js_prec_axa=$(awk  '/Results of Points-To Analysis/{flag=1} flag && /\| Precision/{printf "%.1f", $8; exit}' /workspace/precision_js.log)

# Extract metrics for Table 3 from Native log
nat_fp_opal=$(awk '/Results of Points-To Analysis/{flag=1} flag && /\| False Positives/{print $6; exit}' /workspace/precision_native.log)
nat_fp_axa=$(awk  '/Results of Points-To Analysis/{flag=1} flag && /\| False Positives/{print $8; exit}' /workspace/precision_native.log)
nat_fn_opal=$(awk '/Results of Points-To Analysis/{flag=1} flag && /\| False Negatives/{print $6; exit}' /workspace/precision_native.log)
nat_fn_axa=$(awk  '/Results of Points-To Analysis/{flag=1} flag && /\| False Negatives/{print $8; exit}' /workspace/precision_native.log)
nat_prec_opal=$(awk '/Results of Points-To Analysis/{flag=1} flag && /\| Precision/{printf "%.1f", $6; exit}' /workspace/precision_native.log)
nat_prec_axa=$(awk  '/Results of Points-To Analysis/{flag=1} flag && /\| Precision/{printf "%.1f", $8; exit}' /workspace/precision_native.log)

# Write reproduction results table to /workspace/repro.txt
cat > /workspace/repro.txt <<EOT
**Table 3: Precision And Recall of Points-To-Sets**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    | ${js_fn_opal} | ${js_fn_axa} | ${nat_fn_opal} | ${nat_fn_axa} |
| False Positives    | ${js_fp_opal} | ${js_fp_axa} | ${nat_fp_opal} | ${nat_fp_axa} |
| Precision          | ${js_prec_opal} % | ${js_prec_axa} % | ${nat_prec_opal} % | ${nat_prec_axa} % |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
