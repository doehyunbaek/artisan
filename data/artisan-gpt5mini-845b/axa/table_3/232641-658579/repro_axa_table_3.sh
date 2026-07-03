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
# Section 3: Reproduction commands (safer logging)
docker load -i axa-artifact-image.tar || true
docker rm -f axa_container >/dev/null 2>&1 || true
docker run -d --init --entrypoint bash --name axa_container axaimage -c 'sleep infinity'
# Run JS precision/recall and save full logs (but only extract summary later)
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh" > /workspace/repro_js_full.txt 2>&1 || true
# Run Native precision/recall and save full logs
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh" > /workspace/repro_native_full.txt 2>&1 || true
# Extract only the summary lines into repro.txt to keep input small for formatter
grep -E -i 'false negatives|false positives|precision' /workspace/repro_js_full.txt /workspace/repro_native_full.txt > /workspace/repro.txt || true
if [ ! -s /workspace/repro.txt ]; then
  echo "No summary lines found in repro outputs." > /workspace/repro.txt
fi
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
