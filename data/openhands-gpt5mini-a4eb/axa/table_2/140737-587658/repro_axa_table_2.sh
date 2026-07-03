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
# Download the artifact zip from Zenodo and extract
curl -sL 'https://zenodo.org/records/13374578/files/axa-artifact.zip?download=1' -o /workspace/axa-artifact.zip
unzip -q -o /workspace/axa-artifact.zip -d /workspace/axa-artifact

# Section 2.5: Patch Dockerfile to avoid an unavailable upstream binary
# (Replaces upstream Maven binary download with apt install maven)
python3 - <<'PY'
import re,sys
p='/workspace/axa-artifact/docker/Dockerfile'
text=open(p).read()
if 'dlcdn.apache.org/maven' in text:
    replacement=('''# Install Maven via apt to avoid unavailable upstream binary
RUN apt-get update && apt-get install -y maven
ENV M2_HOME=/usr/share/maven
ENV PATH="/usr/share/maven/bin:$PATH"
#\n''')
    text=re.sub(r"# Install Maven.*?#\n", replacement, text, flags=re.S)
    open(p,'w').write(text)
    print('Patched Dockerfile to install maven via apt')
else:
    print('Dockerfile does not need patching')
PY

# Section 3: Reproduction commands
# Build the docker image (this may take a long time)
cd /workspace/axa-artifact && ./createContainer.sh

# Start container in detached mode
container_id=$(docker run -d --init --entrypoint bash axaimage -c 'sleep infinity')
echo $container_id > /workspace/axa_container_id.txt

# Run JS benchmark and Native benchmark inside the container and capture outputs
docker exec $container_id /bin/bash --noprofile --norc -c "/runner/runJSBenchmark.sh" > /workspace/repro_js.txt 2>&1 || true
docker exec $container_id /bin/bash --noprofile --norc -c "/runner/runNativeBenchmark.sh" > /workspace/repro_native.txt 2>&1 || true

# Combine the relevant summary lines into a single reproduction file
# Extract the table portion from each output and create a combined table
js_table=$(grep -n "| Category\|" -n /workspace/repro_js.txt -n || true)
# Fallback: grep the known category lines
printf "| Category                    | Passed/Test JavaScript | Passed/Test Native |\n" > /workspace/repro.txt
for category in "Unidirectional Execution" "Interleaved Execution" "Mutual Recursion" "Unidirectional State Access" "Bidirectional State Access"; do
  js_line=$(grep -i "${category}" /workspace/repro_js.txt | head -n1 | sed -e 's/^.*|/|/' -e 's/\s*$//') || true
  native_line=$(grep -i "${category}" /workspace/repro_native.txt | head -n1 | sed -e 's/^.*|/|/' -e 's/\s*$//') || true
  # If lines are empty, try alternate formatting
  if [ -z "$js_line" ]; then js_line="| ${category} | (no-data) "; fi
  if [ -z "$native_line" ]; then native_line="| ${category} | (no-data) "; fi
  # Extract the numeric parts
  js_num=$(echo "$js_line" | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
  native_num=$(echo "$native_line" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
  printf "| %-27s | %-20s | %-16s |\n" "$category" "$js_num" "$native_num" >> /workspace/repro.txt
done

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
