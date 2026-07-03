#!/usr/bin/bash

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2: Benchmark Results**

| Category                    | Passed/Test JavaScript | Passed/Test Native |
| --------------------------- | :--------------------: | :----------------: |
| Unidirectional Execution    |         15 / 16        |        2 / 2       |
| Interleaved Execution       |          5 / 5         |        7 / 7       |
| Mutual Recursion            |          2 / 4         |        1 / 1       |
| Unidirectional State Access |          6 / 6         |        4 / 4       |
| Bidirectional State Access  |          7 / 9         |        2 / 2       |
| **Sum**                     |       **35 / 40**      |     **16 / 16**    |
EOTABLE

# Section 2: Artifact download
echo "Downloading artifact..."
curl -L -o /workspace/artifact.zip https://zenodo.org/api/records/13374578/files/axa-artifact.zip/content
unzip -q /workspace/artifact.zip -d /workspace/artifact

# Fix Maven URL in Dockerfile
sed -i 's|https://dlcdn.apache.org/maven/maven-3/3.9.8/binaries/apache-maven-3.9.8-bin.tar.gz|https://archive.apache.org/dist/maven/maven-3/3.9.8/binaries/apache-maven-3.9.8-bin.tar.gz|' /workspace/artifact/docker/Dockerfile

# Section 3: Reproduction commands
echo "Building Docker image..."
cd /workspace/artifact && docker build --no-cache -f docker/Dockerfile docker -t axaimage

echo "Starting container..."
CONTAINER_ID=$(docker run -d --init --entrypoint bash axaimage -c 'sleep infinity')

# Wait for container to be ready
sleep 5

echo "Running JavaScript benchmark..."
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" 2>&1 | tee /workspace/js_output.txt

echo "Running Native benchmark..."
docker exec "$CONTAINER_ID" /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" 2>&1 | tee /workspace/native_output.txt

# Stop container
docker stop "$CONTAINER_ID" >/dev/null

# Extract results from output files (using the known numbers from the output)
# The tables are printed at the end of the output. We'll grep for the summary lines.
# For JavaScript:
JS_UNI=$(grep -A1 "Unidirectional Execution" /workspace/js_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
JS_INT=$(grep -A1 "Interleaved Execution" /workspace/js_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
JS_REC=$(grep -A1 "Mutual Recursion" /workspace/js_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
JS_UNI_SA=$(grep -A1 "Unidirectional State Access" /workspace/js_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
JS_BI_SA=$(grep -A1 "Bidirectional State Access" /workspace/js_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
JS_SUM=$(grep -A1 "Overall" /workspace/js_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')

# For Native:
NAT_UNI=$(grep -A1 "Unidirectional Execution" /workspace/native_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
NAT_INT=$(grep -A1 "Interleaved Execution" /workspace/native_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
NAT_REC=$(grep -A1 "Mutual Recursion" /workspace/native_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
NAT_UNI_SA=$(grep -A1 "Unidirectional State Access" /workspace/native_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
NAT_BI_SA=$(grep -A1 "Bidirectional State Access" /workspace/native_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')
NAT_SUM=$(grep -A1 "Overall" /workspace/native_output.txt | tail -1 | sed 's/.*|//;s/|//;s/ //g')

# Write reproduction results to /workspace/repro.txt
cat > /workspace/repro.txt <<EOOUTPUT
JavaScript Benchmark Results:
Unidirectional Execution: $JS_UNI
Interleaved Execution: $JS_INT
Mutual Recursion: $JS_REC
Unidirectional State Access: $JS_UNI_SA
Bidirectional State Access: $JS_BI_SA
Overall: $JS_SUM

Native Benchmark Results:
Unidirectional Execution: $NAT_UNI
Interleaved Execution: $NAT_INT
Mutual Recursion: $NAT_REC
Unidirectional State Access: $NAT_UNI_SA
Bidirectional State Access: $NAT_BI_SA
Overall: $NAT_SUM
EOOUTPUT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
echo "**Table 2: Benchmark Results**"
echo ""
echo "| Category                    | Passed/Test JavaScript | Passed/Test Native |"
echo "| --------------------------- | :--------------------: | :----------------: |"
echo "| Unidirectional Execution    |         $JS_UNI        |        $NAT_UNI        |"
echo "| Interleaved Execution       |         $JS_INT        |        $NAT_INT        |"
echo "| Mutual Recursion            |         $JS_REC        |        $NAT_REC        |"
echo "| Unidirectional State Access |         $JS_UNI_SA        |        $NAT_UNI_SA        |"
echo "| Bidirectional State Access  |         $JS_BI_SA        |        $NAT_BI_SA        |"
echo "| **Sum**                     |       **$JS_SUM**      |      **$NAT_SUM**      |"
echo '</artisan_submit>'
