#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 1: Benchmark programs**

| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |
| --- | --- | --- | --- | --- | --- |
| bc-1.07.1 | ????? | ????? | ? | ? | ? |
| binn-3.0** | ???? | ???? | ? | ? | ? |
| brotli-1.0.9** | ????? | ?????? | ? | ? | ? |
| cflow-1.7 | ????? | ????? | ? | ? | ? |
| compton* | ???? | ????? | ? | ? | ? |
| cpio-2.14 | ????? | ????? | ?? | ? | ? |
| diffutils-3.10 | ????? | ????? | ? | ? | ? |
| enscript-1.6.6 | ????? | ????? | ? | ? | ? |
| findutils-4.9.0 | ????? | ?????? | ?? | ? | ? |
| gawk-5.2.2 | ????? | ?????? | ?? | ?? | ? |
| glpk-5.0 | ????? | ?????? | ?? | ?? | ? |
| gprolog-1.5.0 | ????? | ????? | ? | ? | ? |
| grep-3.11 | ????? | ????? | ?? | ? | ? |
| gzip-1.12 | ????? | ????? | ? | ? | ? |
| hiredis* | ???? | ????? | ? | ? | ? |
| make-4.4.1 | ????? | ????? | ? | ? | ? |
| minilisp* | ??? | ???? | ? | ? | ? |
| mtools-4.0.43 | ????? | ????? | ? | ? | ? |
| nano-7.2 | ????? | ????? | ? | ? | ? |
| nettle-3.9 | ????? | ????? | ? | ? | ? |
| patch-2.7.6 | ????? | ?????? | ? | ? | ? |
| php-rdkafka* | ???? | ????? | ? | ? | ? |
| pocketlang* | ????? | ????? | ? | ? | ? |
| pth-2.0.7 | ???? | ????? | ? | ? | ? |
| raygui* | ???? | ????? | ? | ? | ? |
| rcs-5.10.1 | ????? | ????? | ? | ? | ? |
| screen-4.9.0 | ????? | ????? | ? | ? | ? |
| sed-4.9 | ????? | ????? | ? | ? | ? |
| shairport* | ???? | ????? | ? | ? | ? |
| tar-1.34 | ????? | ?????? | ?? | ?? | ? |
| tinyproxy* | ???? | ????? | ? | ? | ? |
| twemproxy* | ????? | ????? | ? | ? | ? |
| uucp-1.07 | ????? | ????? | ? | ? | ? |
| webdis* | ????? | ????? | ? | ? | ? |
| wget-1.21.4 | ????? | ?????? | ? | ? | ? |
| Total |  |  | ??? | ??? | ?? |

EOTABLE
# Section 2: Artifact download
artisan get https://zenodo.org/records/13373683
# Section 3: Reproduction commands (populate from reviewed steps)
# Pull Docker image if not present
docker pull kaistplrg/urcrat:ase2024 2>/dev/null || true
# Start Docker container in detached mode
container_id=$(docker run -d --init --entrypoint bash kaistplrg/urcrat:ase2024 -c 'sleep infinity')
echo "Container started: $container_id"
# Wait for container to be ready
sleep 5
# Run size.sh to get C LOC and Rust LOC, output to home directory
docker exec $container_id /bin/bash --noprofile --norc -c "cd /home/ubuntu && size.sh > size_output.txt 2>&1"
# Run run.sh to get union analysis (takes ~2 hours), output to home directory
docker exec $container_id /bin/bash --noprofile --norc -c "cd /home/ubuntu && run.sh > run_output.txt 2>&1"
# Process the outputs to create Table 1
docker exec $container_id /bin/bash --noprofile --norc -c '
cd /home/ubuntu
# Define program names as in Table 1
programs="bc-1.07.1 binn-3.0** brotli-1.0.9** cflow-1.7 compton* cpio-2.14 diffutils-3.10 enscript-1.6.6 findutils-4.9.0 gawk-5.2.2 glpk-5.0 gprolog-1.5.0 grep-3.11 gzip-1.12 hiredis* make-4.4.1 minilisp* mtools-4.0.43 nano-7.2 nettle-3.9 patch-2.7.6 php-rdkafka* pocketlang* pth-2.0.7 raygui* rcs-5.10.1 screen-4.9.0 sed-4.9 shairport* tar-1.34 tinyproxy* twemproxy* uucp-1.07 webdis* wget-1.21.4"
# Initialize totals
total_u=0; total_c=0; total_i=0
# Output table header
echo "**Table 1: Benchmark programs**"
echo ""
echo "| Name | C LOC | Rust LOC | #Unions | #Candidates | #Identified |"
echo "| --- | --- | --- | --- | --- | --- |"
# Process each program
for prog in $programs; do
    # Remove asterisks for key
    key=$(echo "$prog" | sed -e "s/\*//g")
    # Extract C LOC and Rust LOC from size_output.txt
    size_line=$(grep -E "^[0-9]+[[:space:]]+[0-9]+[[:space:]]+$key$" size_output.txt)
    if [ -n "$size_line" ]; then
        c_loc=$(echo "$size_line" | awk "{print \$1}")
        rs_loc=$(echo "$size_line" | awk "{print \$2}")
    else
        c_loc=""
        rs_loc=""
    fi
    # Extract unions, candidates, identified from run_output.txt
    run_line=$(grep -E "^[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+$key$" run_output.txt)
    if [ -n "$run_line" ]; then
        unions=$(echo "$run_line" | awk "{print \$1}")
        candidates=$(echo "$run_line" | awk "{print \$2}")
        identified=$(echo "$run_line" | awk "{print \$3}")
        # Update totals
        total_u=$((total_u + unions))
        total_c=$((total_c + candidates))
        total_i=$((total_i + identified))
    else
        unions=""
        candidates=""
        identified=""
    fi
    # Output row
    echo "| $prog | $c_loc | $rs_loc | $unions | $candidates | $identified |"
done
# Output total row
echo "| Total |  |  | $total_u | $total_c | $total_i |"
' > /workspace/repro.txt
# Stop and remove the container
docker stop $container_id >/dev/null 2>&1
docker rm $container_id >/dev/null 2>&1
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
