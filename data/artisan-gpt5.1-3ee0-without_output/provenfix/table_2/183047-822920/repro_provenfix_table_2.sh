#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**

| Project         | Failed Assert |
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

# Section 3: Reproduction commands
# Pull and start the official ProveNFix Docker image
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker run -d --init --name provenfix_table2_repro --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Initialize reproduction table
cat > /workspace/repro.txt <<'REPROTABLE'
| Project         | Failed Assert |
| --------------- | ------------: |
REPROTABLE

total=0

run_project() {
  local name="$1"
  local spec="$2"
  local bench="$3"
  # Run the full ProveNFix pipeline for this project inside the container
  local output
  output="$(docker exec provenfix_table2_repro /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp $spec spec.c && cd $bench && make clean && /home/infer_TempFix/infer/bin/tempFix")"
  # Extract the first [Failed Assert] value from stdout
  local val
  val="$(printf '%s\n' "$output" | grep -m1 '\[Failed' | sed -E 's/[^0-9]*([0-9]+).*/\1/')"
  [ -z "$val" ] && val=0
  printf '| %-14s | %12s |\n' "$name" "$val" >> /workspace/repro.txt
  total=$((total + val))
}

# Run ProveNFix for each Table 2 project
run_project "Swoole"          "spec_Swoole.c"          "/home/benchmarks-RQ1N2/swoole-src"
run_project "lxc"             "spec_Lxc.c"             "/home/benchmarks-RQ1N2/lxc"
run_project "WavPack"         "spec_WavPack.c"         "/home/benchmarks-RQ1N2/WavPack"
run_project "flex"            "spec_flex.c"            "/home/benchmarks-RQ1N2/flex"
run_project "p11-kit"         "spec_p11.c"             "/home/benchmarks-RQ1N2/p11-kit"
run_project "x264"            "spec-x264.c"            "/home/benchmarks-RQ1N2/x264"
run_project "recutils-1.8"    "spec-recutils.c"        "/home/benchmarks-RQ1N2/recutils-1.8"
run_project "inetutils-1.9.4" "spec-inetutils.c"       "/home/benchmarks-RQ1N2/inetutils-1.9.4"
run_project "snort-2.9.13"    "spec_snort-2.9.13.c"    "/home/benchmarks-RQ1N2/snort-2.9.13"
run_project "grub"            "spec_Grub.c"            "/home/benchmarks-RQ1N2/grub"

# Append total row
printf '| **Total**       |       **%d** |\n' "$total" >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
