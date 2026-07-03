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
echo "Downloading artifact..."
curl -L -o /workspace/axa-artifact.zip "https://zenodo.org/records/13374578/files/axa-artifact.zip"
mkdir -p /workspace/artifact
cd /workspace/artifact
unzip -q /workspace/axa-artifact.zip

# Patch Dockerfile to fix broken URLs
sed -i 's|https://dlcdn.apache.org/maven/maven-3/3.9.8/binaries/apache-maven-3.9.8-bin.tar.gz|https://archive.apache.org/dist/maven/maven-3/3.9.8/binaries/apache-maven-3.9.8-bin.tar.gz|' docker/Dockerfile
sed -i 's|https://dlcdn.apache.org//ant/binaries/apache-ant-1.10.14-bin.zip|https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.14-bin.zip|' docker/Dockerfile

# Build Docker image
echo "Building Docker image (this may take a while)..."
./createContainer.sh 2>&1 | tee /workspace/build.log

# Start container in background
docker run -d --init --name axa_container --entrypoint bash axaimage -c 'sleep infinity'

# Wait a bit for container to be ready
sleep 5

# Section 3: Reproduction commands
echo "Running precision recall for JavaScript..."
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/precisionRecallJS.sh" 2>&1 | tee /workspace/js_results.log
echo "Running precision recall for Native..."
docker exec axa_container /bin/bash --noprofile --norc -c "/runner/precisionRecallNative.sh" 2>&1 | tee /workspace/native_results.log

# Extract numbers from logs
parse_table() {
    local logfile=$1
    # Remove [info] prefix and select lines with pipes
    grep -E '^\s*\[info\]\s*\|' "$logfile" | sed 's/^\[info\] //' > /tmp/table.txt
    # Extract False Positives line
    fp_line=$(grep "False Positives" /tmp/table.txt)
    fn_line=$(grep "False Negatives" /tmp/table.txt)
    prec_line=$(grep "Precision" /tmp/table.txt)
    # Use awk to get columns (fields separated by '|')
    fp1=$(echo "$fp_line" | awk -F '|' '{print $3}' | xargs)
    fp2=$(echo "$fp_line" | awk -F '|' '{print $4}' | xargs)
    fn1=$(echo "$fn_line" | awk -F '|' '{print $3}' | xargs)
    fn2=$(echo "$fn_line" | awk -F '|' '{print $4}' | xargs)
    prec1=$(echo "$prec_line" | awk -F '|' '{print $3}' | xargs)
    prec2=$(echo "$prec_line" | awk -F '|' '{print $4}' | xargs)
    # Output as space-separated: fp1 fn1 prec1 fp2 fn2 prec2
    echo "$fp1 $fn1 $prec1 $fp2 $fn2 $prec2"
}

js_numbers=$(parse_table /workspace/js_results.log)
native_numbers=$(parse_table /workspace/native_results.log)

# Read into variables
read fp_js_opal fn_js_opal prec_js_opal fp_js_axa fn_js_axa prec_js_axa <<< "$js_numbers"
read fp_native_opal fn_native_opal prec_native_opal fp_native_axa fn_native_axa prec_native_axa <<< "$native_numbers"

# Create reproduced table
cat > /workspace/repro.txt <<REPRO
**Table 3: Precision And Recall of Points-To-Sets (Reproduced)**

| Points-To Analysis | Java/JS OPAL | Java/JS AXA | Java/Native OPAL | Java/Native AXA |
| ------------------ | -----------: | ----------: | ---------------: | --------------: |
| False Negatives    | $(printf "%12d" "$fn_js_opal") | $(printf "%11d" "$fn_js_axa") | $(printf "%16d" "$fn_native_opal") | $(printf "%15d" "$fn_native_axa") |
| False Positives    | $(printf "%12d" "$fp_js_opal") | $(printf "%11d" "$fp_js_axa") | $(printf "%16d" "$fp_native_opal") | $(printf "%15d" "$fp_native_axa") |
| Precision          | $(printf "%12s %%" "$prec_js_opal") | $(printf "%11s %%" "$prec_js_axa") | $(printf "%16s %%" "$prec_native_opal") | $(printf "%15s %%" "$prec_native_axa") |

REPRO

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'