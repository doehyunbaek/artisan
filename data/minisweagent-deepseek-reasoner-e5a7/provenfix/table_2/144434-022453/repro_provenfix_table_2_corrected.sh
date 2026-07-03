#!/usr/bin/bash

# Section 1: Expected table (already in /workspace/expected.md, so just reference it)

# Section 2: Start Docker container and run analyses
echo "=== Starting Docker container ==="
CONTAINER_ID=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity')
echo "Container ID: $CONTAINER_ID"

# Function to run analysis for a project
analyze_project() {
    local project_name="$1"
    local spec_file="$2"
    local bench_dir="$3"
    
    echo "=== Analyzing $project_name ==="
    
    # Run the commands in the container
    docker exec $CONTAINER_ID /bin/bash --noprofile --norc -c "
        set -e
        cd /home/infer_TempFix
        git reset --hard
        git checkout main
        ./compile > /tmp/compile.log 2>&1
        cp $spec_file spec.c
        cd /home/benchmarks-RQ1N2/$bench_dir
        make clean > /dev/null 2>&1
        /home/infer_TempFix/infer/bin/tempFix > /tmp/analysis_output.txt 2>&1
        grep '\[Failed Assert\]' /tmp/analysis_output.txt | awk '{print \$3}'
    " 2>/dev/null
}

# Create file to store results
RESULTS_FILE="/workspace/results.txt"
> "$RESULTS_FILE"

# List of projects with correct spec file names and benchmark directories
PROJECTS=(
    "Swoole|spec_Swoole.c|swoole-src"
    "lxc|spec_Lxc.c|lxc"
    "WavPack|spec_WavPack.c|WavPack"
    "flex|spec_flex.c|flex"
    "p11-kit|spec_p11.c|p11-kit"
    "x264|spec-x264.c|x264"
    "recutils-1.8|spec-recutils.c|recutils-1.8"
    "inetutils-1.9.4|spec-inetutils.c|inetutils-1.9.4"
    "snort-2.9.13|spec_snort-2.9.13.c|snort-2.9.13"
    "grub|spec_Grub.c|grub"
)

TOTAL=0
for project_entry in "${PROJECTS[@]}"; do
    IFS='|' read -r project_name spec_file bench_dir <<< "$project_entry"
    failed_assert=$(analyze_project "$project_name" "$spec_file" "$bench_dir")
    if [ -z "$failed_assert" ]; then
        failed_assert="N/A"
    else
        TOTAL=$((TOTAL + failed_assert))
    fi
    echo "$project_name|$failed_assert" >> "$RESULTS_FILE"
    echo "$project_name: $failed_assert"
done

# Stop and remove container
docker stop $CONTAINER_ID > /dev/null 2>&1
docker rm $CONTAINER_ID > /dev/null 2>&1

# Section 3: Output the table
echo '<artisan_submit>'
echo "**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**"
echo ""
echo "| Project         | Failed Assert |"
echo "| --------------- | ------------: |"

while IFS='|' read -r project count; do
    printf "| %-15s | %13s |\n" "$project" "$count"
done < "$RESULTS_FILE"

printf "| **Total**       |       **%3d** |\n" "$TOTAL"
echo '</artisan_submit>'

# Save to repro.txt
echo "Reproduction results saved to /workspace/repro.txt"
cat "$RESULTS_FILE" > /workspace/repro.txt
echo "Total: $TOTAL" >> /workspace/repro.txt

rm -f "$RESULTS_FILE"
echo "=== Reproduction completed ==="
