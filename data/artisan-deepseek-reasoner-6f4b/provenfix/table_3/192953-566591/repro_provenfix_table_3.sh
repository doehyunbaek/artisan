#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          |            ?? |
| lxc             |            ?? |
| WavPack         |            ?? |
| flex            |            ?? |
| p11-kit         |            ?? |
| x264            |            ?? |
| recutils-1.8    |            ?? |
| inetutils-1.9.4 |            ?? |
| snort-2.9.13    |            ?? |
| grub            |            ?? |
| **Total**       |       **???** |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/songyahui/infer_TempFix
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull Docker image and start container
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
CONTAINER_ID=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity')
echo "Container started: $CONTAINER_ID"
sleep 5
# Function to run experiment for a project
run_experiment() {
    local project=$1
    local spec=$2
    docker exec $CONTAINER_ID bash -c "cd /home/infer_TempFix && cp $spec spec.c"
    docker exec $CONTAINER_ID bash -c "cd /home/benchmarks-RQ1N2/$project && make clean > /dev/null 2>&1 || true"
    output=$(docker exec $CONTAINER_ID /home/infer_TempFix/infer/bin/tempFix 2>&1)
    echo "$output"
}
# Extract repaired bugs from output
extract_repaired() {
    echo "$1" | grep -o '\[Repaired Bugs\][[:space:]]*[0-9]*' | grep -o '[0-9]*'
}
# Run for each project
projects=("swoole-src" "lxc" "WavPack" "flex" "p11-kit" "x264" "recutils-1.8" "inetutils-1.9.4" "snort-2.9.13" "grub")
specs=("spec_Swoole.c" "spec_Lxc.c" "spec_WavPack.c" "spec_flex.c" "spec_p11.c" "spec-x264.c" "spec-recutils.c" "spec-inetutils.c" "spec_snort-2.9.13.c" "spec_Grub.c")
results=()
total=0
for i in "${!projects[@]}"; do
    echo "Running experiment for ${projects[$i]}..."
    output=$(run_experiment "${projects[$i]}" "${specs[$i]}")
    repaired=$(extract_repaired "$output")
    if [ -z "$repaired" ]; then
        repaired="??"
    else
        total=$((total + repaired))
    fi
    results+=("$repaired")
    echo "${projects[$i]}: $repaired"
done
# Write results to repro.txt
echo "Project,Repaired Bugs" > /workspace/repro.txt
for i in "${!projects[@]}"; do
    echo "${projects[$i]},${results[$i]}" >> /workspace/repro.txt
done
echo "Total,$total" >> /workspace/repro.txt
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
