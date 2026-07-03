#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          |            98 |
| lxc             |            56 |
| WavPack         |            52 |
| flex            |            24 |
| p11-kit         |            37 |
| x264            |            21 |
| recutils-1.8    |            72 |
| inetutils-1.9.4 |            37 |
| snort-2.9.13    |            85 |
| grub            |            12 |
| **Total**       |       **494** |
EOTABLE

# Section 2: Artifact download
artisan get https://github.com/songyahui/infer_TempFix

# Section 3: Reproduction commands (populate from reviewed steps)

# Use Docker image as recommended in the artifact README
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu

# Ensure a fresh container for this reproduction
docker rm -f provenfix_table3 >/dev/null 2>&1 || true

# Start container in detached mode with a bash entrypoint that sleeps
docker run -d --init --name provenfix_table3 --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Prepare ProveNFix inside the container: use main branch and compile
docker exec provenfix_table3 /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && git reset --hard && git checkout main && ./compile"

# Helper to run one project and extract the '[Repaired   Bugs]' count
run_proj() {
  local spec_file="$1"
  local bench_dir="$2"
  local tag="$3"
  # Run ProveNFix for this project, capturing verbose output in a log file
  docker exec provenfix_table3 /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp ${spec_file} spec.c && cd ${bench_dir} && make clean >/tmp/make_clean_${tag}.log 2>&1 && /home/infer_TempFix/infer/bin/tempFix >/tmp/tempfix_${tag}.log 2>&1"
  # Extract the repaired bug count from the summary line
  docker exec provenfix_table3 /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/tempfix_${tag}.log | tail -n 1" | awk '{print $3}'
}

# Run all 10 projects sequentially
S_Swoole=$(run_proj "spec_Swoole.c"        "/home/benchmarks-RQ1N2/swoole-src"        "swoole")
S_lxc=$(run_proj "spec_Lxc.c"             "/home/benchmarks-RQ1N2/lxc"              "lxc")
S_WavPack=$(run_proj "spec_WavPack.c"     "/home/benchmarks-RQ1N2/WavPack"          "wavpack")
S_flex=$(run_proj "spec_flex.c"           "/home/benchmarks-RQ1N2/flex"             "flex")
S_p11=$(run_proj "spec_p11.c"             "/home/benchmarks-RQ1N2/p11-kit"          "p11")
S_x264=$(run_proj "spec-x264.c"           "/home/benchmarks-RQ1N2/x264"             "x264")
S_rec=$(run_proj "spec-recutils.c"        "/home/benchmarks-RQ1N2/recutils-1.8"     "recutils")
S_inet=$(run_proj "spec-inetutils.c"      "/home/benchmarks-RQ1N2/inetutils-1.9.4"  "inetutils")
S_snort=$(run_proj "spec_snort-2.9.13.c"  "/home/benchmarks-RQ1N2/snort-2.9.13"     "snort")
S_grub=$(run_proj "spec_Grub.c"           "/home/benchmarks-RQ1N2/grub"             "grub")

TOTAL=$((S_Swoole + S_lxc + S_WavPack + S_flex + S_p11 + S_x264 + S_rec + S_inet + S_snort + S_grub))

# Emit the reproduced table
cat > /workspace/repro.txt <<EOT
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          |            $S_Swoole |
| lxc             |            $S_lxc |
| WavPack         |            $S_WavPack |
| flex            |            $S_flex |
| p11-kit         |            $S_p11 |
| x264            |            $S_x264 |
| recutils-1.8    |            $S_rec |
| inetutils-1.9.4 |            $S_inet |
| snort-2.9.13    |            $S_snort |
| grub            |            $S_grub |
| **Total**       |       **$TOTAL** |
EOT

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
