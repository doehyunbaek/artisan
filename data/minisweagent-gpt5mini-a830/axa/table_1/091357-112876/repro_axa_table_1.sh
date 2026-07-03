#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Extensions and Changes of Single-Language Analyses for Integration into AXA**

| Analysis   | Detector             | Lattice | Solver | Connector | Translator (to Java) | Total |
| ---------- | -------------------- | ------: | -----: | --------: | -------------------- | ----- |
| Java       | 836                  | 60 (JS) |      0 |         0 | –                    | 896   |
| JavaScript | 166 + 2              |   90+14 |      2 |       452 | 137                  | 863   |
| Native     | 328                  |     107 |     16 |      1025 | 16                   | 1492  |

EOTABLE

# Section 2: Artifact download
# Download the artifact from Zenodo (record 13374578)
curl -sS -L --fail -o /workspace/axa-artifact.zip "https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1" || curl -sS -L --fail -o /workspace/axa-artifact.zip "https://zenodo.org/record/13374578/files/axa-artifact.zip?download=1"

# Section 3: Reproduction commands (populate from reviewed steps)
# Unpack artifact
unzip -q -d /workspace/axa /workspace/axa-artifact.zip

# Fix known Maven download URL in Dockerfile to use Apache archive mirror (avoids 404)
if [ -f /workspace/axa/docker/Dockerfile ]; then
  sed -i 's|https://dlcdn.apache.org/maven/maven-3/3.9.8/binaries/apache-maven-3.9.8-bin.tar.gz|https://archive.apache.org/dist/maven/maven-3/3.9.8/binaries/apache-maven-3.9.8-bin.tar.gz|' /workspace/axa/docker/Dockerfile || true
fi

# Build the container and prepare environment using the provided script
chmod +x /workspace/axa/createContainer.sh
cd /workspace/axa && ./createContainer.sh

# Start a detached container (sleep infinity pattern) and record its id
CID=$(docker run -d --init --entrypoint bash axaimage -c 'sleep infinity') || { echo "Failed to start container" >&2; exit 1; }
echo "$CID" > /workspace/axacontainer.id

# Run the LOC printing script inside the container and capture output
docker exec "$CID" /bin/bash --noprofile --norc -c "/runner/printLOCs.sh" > /workspace/repro.txt 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission.txt
echo '--- Expected table (expected.md) ---' >> /workspace/repro_submission.txt
cat /workspace/expected.md >> /workspace/repro_submission.txt
echo '--- Reproduced output (repro.txt) ---' >> /workspace/repro_submission.txt
cat /workspace/repro.txt >> /workspace/repro_submission.txt
echo '</artisan_submit>' >> /workspace/repro_submission.txt

echo "Reproduction finished. Files created:"
echo " - /workspace/expected.md"
echo " - /workspace/repro.txt"
echo " - /workspace/repro_submission.txt"
