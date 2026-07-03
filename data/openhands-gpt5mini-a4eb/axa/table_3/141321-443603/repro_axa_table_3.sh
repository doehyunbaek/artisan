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
# (Downloads the small axa-artifact.zip and extracts it)
if [ ! -f /workspace/axa-artifact.zip ]; then
  echo "Downloading axa-artifact.zip from zenodo..."
  curl -L "https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1" -o /workspace/axa-artifact.zip
fi
if [ ! -d /workspace/axa-artifact ]; then
  echo "Extracting axa-artifact.zip..."
  unzip -q /workspace/axa-artifact.zip -d /workspace/axa-artifact
fi

# Section 3: Reproduction commands (populate from reviewed steps)
# NOTE: These commands assume Docker is installed and the current user can run docker.
# The docker image build is heavy and may take a long time (and substantial memory).
# We follow the recommended pattern: build image, run container in background, exec commands.

# Build the docker image (this mirrors createContainer.sh)
cd /workspace/axa-artifact/docker

echo "Building docker image 'axaimage' (this may take a long time)..."
docker build --no-cache -f Dockerfile . -t axaimage

# Start container in detached sleeping mode
echo "Starting container 'axa_eval' from image 'axaimage'..."
docker run -d --init --entrypoint bash --name axa_eval axaimage -c 'sleep infinity'

# Run precision/recall scripts inside container and capture their stdout on the host
echo "Running precisionRecallJS.sh inside container... (this will instrument, run, and analyze JS benchmarks)"
docker exec axa_eval /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh" > /workspace/repro_js.txt 2>&1 || true

echo "Running precisionRecallNative.sh inside container... (this will instrument, run, and analyze Native benchmarks)"
docker exec axa_eval /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh" > /workspace/repro_native.txt 2>&1 || true

# Optionally stop and remove the container
# docker stop axa_eval && docker rm axa_eval

# Combine and try to extract the important numbers into repro.txt
echo "Formatting results into /workspace/repro.txt"
{
  echo "Reproduction outputs for Table 3:"
  echo "\n---- precisionRecallJS.sh output ----\n"
  sed -n '1,200p' /workspace/repro_js.txt 2>/dev/null || true
  echo "\n---- precisionRecallNative.sh output ----\n"
  sed -n '1,200p' /workspace/repro_native.txt 2>/dev/null || true
  echo "\n---- Parsed (best-effort) summary ----\n"
  # Try to grep for typical summary lines; if not present, include a note
  echo "Java/JS OPAL - False Negatives: " $(grep -Ei "false negatives|false-negative|false_negatives" -m1 /workspace/repro_js.txt || echo "N/A")
  echo "Java/JS AXA  - False Negatives: " $(grep -Ei "false negatives|false-negative|false_negatives" -m1 /workspace/repro_js.txt || echo "N/A")
  echo "Java/Native OPAL - False Negatives: " $(grep -Ei "false negatives|false-native" -m1 /workspace/repro_native.txt || echo "N/A")
  echo "Java/Native AXA  - False Negatives: " $(grep -Ei "false negatives|false-native" -m1 /workspace/repro_native.txt || echo "N/A")
} > /workspace/repro.txt

# Section 4: Formatting and submission block

echo '<artisan_submit>'
# Print the produced reproduction file
cat /workspace/repro.txt 2>/dev/null || true

echo '</artisan_submit>'

# End of script
