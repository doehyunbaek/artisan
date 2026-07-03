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
# Download the artifact ZIP from Zenodo and extract it to /workspace/axa-artifact
curl -L -o /workspace/axa-artifact.zip "https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1"
unzip -o /workspace/axa-artifact.zip -d /workspace/axa-artifact

# Section 3: Reproduction commands (populate from reviewed steps)
# NOTE: These commands assume Docker is installed and the current user can run docker commands.
cd /workspace/axa-artifact || exit 1

# Make runner scripts executable
chmod +x createContainer.sh docker/runner/*.sh || true

# Create/build the Docker image as provided by the artifact (this may take several minutes)
./createContainer.sh

# Start the container non-interactively (replace interactive runs). Capture container id.
container=$(docker run -d --init --entrypoint bash axaimage -c 'sleep infinity')
# give container a moment to start
sleep 3

# Execute the precision/recall scripts inside the container and capture outputs.
# Use the recommended docker exec invocation.
docker exec "$container" /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh > /workspace/repro_js.txt 2>&1" || true
docker exec "$container" /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh > /workspace/repro_native.txt 2>&1" || true

# Aggregate outputs into the required repro.txt
echo "==== precisionRecallJS.sh output ====" > /workspace/repro.txt
if [ -f /workspace/repro_js.txt ]; then
  cat /workspace/repro_js.txt >> /workspace/repro.txt
else
  echo "precisionRecallJS.sh did not produce /workspace/repro_js.txt" >> /workspace/repro.txt
fi

echo "" >> /workspace/repro.txt
echo "==== precisionRecallNative.sh output ====" >> /workspace/repro.txt
if [ -f /workspace/repro_native.txt ]; then
  cat /workspace/repro_native.txt >> /workspace/repro.txt
else
  echo "precisionRecallNative.sh did not produce /workspace/repro_native.txt" >> /workspace/repro.txt
fi

# Clean up the container
docker rm -f "$container" >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
# Print a short header, then the reproduction outputs
echo "Reproduction outputs for Table 3 (precision/recall):"
echo ""
if [ -f /workspace/repro.txt ]; then
  cat /workspace/repro.txt
else
  echo "No reproduction output found at /workspace/repro.txt"
fi
echo '</artisan_submit>'
