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
rm -rf /workspace/infer_TempFix || true
artisan get https://github.com/songyahui/infer_TempFix

# Section 3: Reproduction commands (populate from reviewed steps)
: > /workspace/repro.txt
mkdir -p logs

docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker rm -f provenfix 2>/dev/null || true
docker run -d --init --name provenfix --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

run_case() {
  local name="$1"
  local spec="$2"
  local path="$3"
  echo "Running ${name}..." >&2
  docker exec provenfix /bin/bash --noprofile --norc -c "
    set -e
    cd /home/infer_TempFix && cp ${spec} spec.c
    cd ${path} && make clean
    /home/infer_TempFix/infer/bin/tempFix
  " > "logs/${name}_tempfix.log" 2>&1

  local failed
  failed=$(grep -m1 'Failed Assert' "logs/${name}_tempfix.log" | awk '{print $NF}')
  if [ -z "${failed}" ]; then
    failed=0
  fi
  echo "${name}: ${failed}" >> /workspace/repro.txt
}

run_case "Swoole"          "spec_Swoole.c"          "/home/benchmarks-RQ1N2/swoole-src"
run_case "lxc"             "spec_Lxc.c"             "/home/benchmarks-RQ1N2/lxc"
run_case "WavPack"         "spec_WavPack.c"         "/home/benchmarks-RQ1N2/WavPack"
run_case "flex"            "spec_flex.c"            "/home/benchmarks-RQ1N2/flex"
run_case "p11-kit"         "spec_p11.c"             "/home/benchmarks-RQ1N2/p11-kit"
run_case "x264"            "spec-x264.c"            "/home/benchmarks-RQ1N2/x264"
run_case "recutils-1.8"    "spec-recutils.c"        "/home/benchmarks-RQ1N2/recutils-1.8"
run_case "inetutils-1.9.4" "spec-inetutils.c"       "/home/benchmarks-RQ1N2/inetutils-1.9.4"
run_case "snort-2.9.13"    "spec_snort-2.9.13.c"    "/home/benchmarks-RQ1N2/snort-2.9.13"
run_case "grub"            "spec_Grub.c"            "/home/benchmarks-RQ1N2/grub"

total=$(awk -F': ' '/: /{sum+=$2} END{print sum}' /workspace/repro.txt)
echo "Total: ${total}" >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'

get_val() {
  awk -F': ' -v n="$1" '$1==n{print $2}' /workspace/repro.txt
}

{
  echo '**Reproduced Table 2 Failed Assert column (ProveNFix)**'
  echo
  echo '| Project         | Failed Assert |'
  echo '| --------------- | ------------: |'
  echo "| Swoole          | $(get_val Swoole) |"
  echo "| lxc             | $(get_val lxc) |"
  echo "| WavPack         | $(get_val WavPack) |"
  echo "| flex            | $(get_val flex) |"
  echo "| p11-kit         | $(get_val p11-kit) |"
  echo "| x264            | $(get_val x264) |"
  echo "| recutils-1.8    | $(get_val recutils-1.8) |"
  echo "| inetutils-1.9.4 | $(get_val inetutils-1.9.4) |"
  echo "| snort-2.9.13    | $(get_val snort-2.9.13) |"
  echo "| grub            | $(get_val grub) |"
  echo "| **Total**       |       **$(get_val Total)** |"
} > /workspace/table2.md

cat /workspace/table2.md
echo '</artisan_submit>'
