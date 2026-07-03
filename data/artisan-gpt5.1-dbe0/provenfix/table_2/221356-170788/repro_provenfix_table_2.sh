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

# Section 3: Reproduction commands (run ProveNFix in the official Docker image)
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker rm -f prove_n_fix 2>/dev/null || true
docker run -d --init --name prove_n_fix --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Define mapping from project names to specs and benchmark paths (inside the container)
declare -A SPEC_PATHS
declare -A BENCH_PATHS

SPEC_PATHS["Swoole"]="spec_Swoole.c"
BENCH_PATHS["Swoole"]="benchmarks-RQ1N2/swoole-src"

SPEC_PATHS["lxc"]="spec_Lxc.c"
BENCH_PATHS["lxc"]="benchmarks-RQ1N2/lxc"

SPEC_PATHS["WavPack"]="spec_WavPack.c"
BENCH_PATHS["WavPack"]="benchmarks-RQ1N2/WavPack"

SPEC_PATHS["flex"]="spec_flex.c"
BENCH_PATHS["flex"]="benchmarks-RQ1N2/flex"

SPEC_PATHS["p11-kit"]="spec_p11.c"
BENCH_PATHS["p11-kit"]="benchmarks-RQ1N2/p11-kit"

SPEC_PATHS["x264"]="spec-x264.c"
BENCH_PATHS["x264"]="benchmarks-RQ1N2/x264"

SPEC_PATHS["recutils-1.8"]="spec-recutils.c"
BENCH_PATHS["recutils-1.8"]="benchmarks-RQ1N2/recutils-1.8"

SPEC_PATHS["inetutils-1.9.4"]="spec-inetutils.c"
BENCH_PATHS["inetutils-1.9.4"]="benchmarks-RQ1N2/inetutils-1.9.4"

SPEC_PATHS["snort-2.9.13"]="spec_snort-2.9.13.c"
BENCH_PATHS["snort-2.9.13"]="benchmarks-RQ1N2/snort-2.9.13"

SPEC_PATHS["grub"]="spec_Grub.c"
BENCH_PATHS["grub"]="benchmarks-RQ1N2/grub"

PROJECTS=("Swoole" "lxc" "WavPack" "flex" "p11-kit" "x264" "recutils-1.8" "inetutils-1.9.4" "snort-2.9.13" "grub")

declare -A FAILED_ASSERTS

# Run ProveNFix for each project and extract the [Failed Assert] value
for proj in "${PROJECTS[@]}"; do
  spec="${SPEC_PATHS[$proj]}"
  bench="${BENCH_PATHS[$proj]}"
  log="/workspace/${proj//\//_}_tempfix.log"

  docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp $spec spec.c && cd /home/$bench && make clean >/dev/null 2>&1 || true && /home/infer_TempFix/infer/bin/tempFix" > "$log" 2>&1

  fa=$(grep '\[Failed' "$log" | grep 'Assert' | awk '{print $NF}' | tail -n1)
  FAILED_ASSERTS["$proj"]="$fa"
done

# Compute total Failed Assert count
total=0
for proj in "${PROJECTS[@]}"; do
  val="${FAILED_ASSERTS[$proj]}"
  if [ -z "$val" ]; then
    val=0
  fi
  total=$((total + val))
done

# Write the reproduced table using the computed values
cat > /workspace/repro.txt <<EOREPRO
**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**

| Project         | Failed Assert |
| --------------- | ------------: |
| Swoole          | ${FAILED_ASSERTS["Swoole"]} |
| lxc             | ${FAILED_ASSERTS["lxc"]} |
| WavPack         | ${FAILED_ASSERTS["WavPack"]} |
| flex            | ${FAILED_ASSERTS["flex"]} |
| p11-kit         | ${FAILED_ASSERTS["p11-kit"]} |
| x264            | ${FAILED_ASSERTS["x264"]} |
| recutils-1.8    | ${FAILED_ASSERTS["recutils-1.8"]} |
| inetutils-1.9.4 | ${FAILED_ASSERTS["inetutils-1.9.4"]} |
| snort-2.9.13    | ${FAILED_ASSERTS["snort-2.9.13"]} |
| grub            | ${FAILED_ASSERTS["grub"]} |
| **Total**       | **${total}** |

EOREPRO

# Clean up container (optional)
docker rm -f prove_n_fix >/dev/null 2>&1 || true

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
