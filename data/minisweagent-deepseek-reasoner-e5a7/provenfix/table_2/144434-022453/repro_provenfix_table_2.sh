#!/usr/bin/bash

# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**

| Project         | Failed Assert |
| --------------- | ------------: |
| Swoole          |            98 |
| lxc             |            56 |
| WavPack         |            52 |
| flex            |            24 |
| p11-kit         |            37 |
| x264            |            21 |
| recutils-1.8    |            75 |
| inetutils-1.9.4 |            37 |
| snort-2.9.13    |            98 |
| grub            |            12 |
| **Total**       |       **510** |
EOTABLE

# Section 2: Artifact download
echo "=== Downloading artifact ==="
git clone https://github.com/songyahui/infer_TempFix.git /workspace/infer_TempFix_repro

# Section 3: Reproduction commands
echo "=== Starting Docker container ==="
CONTAINER_ID=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity')
echo "Container ID: $CONTAINER_ID"

# Function to run command in container and extract Failed Assert count
run_analysis() {
    local project_name=$1
    local spec_file=$2
    local bench_dir=$3
    
    echo "=== Analyzing $project_name ==="
    
    # Run the analysis commands in the container
    docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "
        cd /home/infer_TempFix && \
        git reset --hard && \
        git checkout main && \
        ./compile > /dev/null 2>&1 && \
        cp $spec_file spec.c && \
        cd /home/benchmarks-RQ1N2/$bench_dir && \
        make clean > /dev/null 2>&1 && \
        /home/infer_TempFix/infer/bin/tempFix 2>&1 | grep -A 1 -B 1 '\[Failed Assert\]'
    "
    
    # Extract the Failed Assert number
    FAILED_ASSERT=$(docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "
        /home/infer_TempFix/infer/bin/tempFix 2>&1 | grep '\[Failed Assert\]' | awk '{print \$3}'
    " 2>/dev/null)
    
    echo "$project_name: $FAILED_ASSERT"
    echo "$project_name|$FAILED_ASSERT" >> /workspace/repro_temp.txt
}

# Create temp file for results
> /workspace/repro_temp.txt

# Run analysis for each project (in order from artifact evaluation)
run_analysis "Swoole" "spec_Swoole.c" "swoole-src"
run_analysis "lxc" "spec_Lxc.c" "lxc"
run_analysis "WavPack" "spec_WavPack.c" "WavPack"
run_analysis "flex" "spec_flex.c" "flex"
run_analysis "p11-kit" "spec_p11.c" "p11-kit"
run_analysis "x264" "spec-x264.c" "x264"
run_analysis "recutils-1.8" "spec_recutils.c" "recutils-1.8"
run_analysis "inetutils-1.9.4" "spec_inetutils.c" "inetutils-1.9.4"
run_analysis "snort-2.9.13" "spec_snort-2.9.13.c" "snort-2.9.13"
run_analysis "grub" "spec_Grub.c" "grub"

# Stop and remove container
echo "=== Cleaning up ==="
docker stop $CONTAINER_ID > /dev/null 2>&1
docker rm $CONTAINER_ID > /dev/null 2>&1

# Section 4: Formatting and submission block
echo '<artisan_submit>'

# Generate the table from collected results
echo "**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**"
echo ""
echo "| Project         | Failed Assert |"
echo "| --------------- | ------------: |"

TOTAL=0
while IFS='|' read -r project count; do
    printf "| %-15s | %13s |\n" "$project" "$count"
    TOTAL=$((TOTAL + count))
done < /workspace/repro_temp.txt

printf "| **Total**       |       **%3d** |\n" "$TOTAL"

echo '</artisan_submit>'

# Save to repro.txt
cat > /workspace/repro.txt <<'EOOUTPUT'
Table 2 Reproduction Results
============================
EOOUTPUT
cat /workspace/repro_temp.txt >> /workspace/repro.txt
echo "Total: $TOTAL" >> /workspace/repro.txt

# Cleanup
rm -f /workspace/repro_temp.txt

echo "=== Reproduction completed ==="
