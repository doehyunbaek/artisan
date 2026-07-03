#!/usr/bin/bash
set -euo pipefail

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

# Section 2: Artifact download (idempotent)
if [ ! -d /workspace/infer_TempFix ]; then
  git clone https://github.com/songyahui/infer_TempFix /workspace/infer_TempFix
fi

# Section 3: Reproduction commands
# Pull and run the docker image as recommended (detached sleep container)
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
container=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity')
echo "Started container: $container"

# Projects mapping: bench dir -> spec file in /home/infer_TempFix
declare -a bench_dirs=("swoole-src" "lxc" "WavPack" "flex" "p11-kit" "x264" "recutils-1.8" "inetutils-1.9.4" "snort-2.9.13" "grub")
declare -a spec_files=("spec_Swoole.c" "spec_Lxc.c" "spec_WavPack.c" "spec_flex.c" "spec_p11.c" "spec-x264.c" "spec-recutils.c" "spec-inetutils.c" "spec_snort-2.9.13.c" "spec_Grub.c")
declare -a proj_names=("Swoole" "lxc" "WavPack" "flex" "p11-kit" "x264" "recutils-1.8" "inetutils-1.9.4" "snort-2.9.13" "grub")

# Prepare output file
: > /workspace/repro.txt

for i in "${!bench_dirs[@]}"; do
  dir="${bench_dirs[$i]}"
  spec="${spec_files[$i]}"
  name="${proj_names[$i]}"
  echo "=== Running project: $name (bench dir: $dir, spec: $spec) ===" | tee -a /workspace/repro.txt

  # Copy spec into place
  docker exec "$container" /bin/bash -lc "cp /home/infer_TempFix/${spec} /home/infer_TempFix/spec.c || true"

  # Run make clean in the benchmark (allow failure)
  docker exec "$container" /bin/bash -lc "cd /home/benchmarks-RQ1N2/${dir} && make clean || true"

  # Run ProveNFix; capture stdout to a temp file inside container to avoid host mount issues
  docker exec "$container" /bin/bash -lc "rm -f /tmp/tempfix_output.txt && /home/infer_TempFix/infer/bin/tempFix > /tmp/tempfix_output.txt 2>&1 || true"

  # Copy the generated detail.txt (if any) out to host workspace for inspection
  docker exec "$container" /bin/bash -lc "test -f /home/infer_TempFix/TempFix-out/detail.txt && true" || true
  docker cp "${container}:/home/infer_TempFix/TempFix-out/detail.txt" "/workspace/${name}_detail.txt" >/dev/null 2>&1 || true

  # Extract the "Failed Assert" summary; prefer the tempfix_output first, fallback to detail.txt
  failed_line=$(docker exec "$container" /bin/bash -lc "grep -n '\\[Failed Assert\\]' /tmp/tempfix_output.txt || true" | sed -n '1p' || true)
  if [ -z "$failed_line" ]; then
    if [ -f "/workspace/${name}_detail.txt" ]; then
      failed_line=$(grep -n '\[Failed Assert\]' "/workspace/${name}_detail.txt" || true | sed -n '1p' || true)
    fi
  fi
  if [ -z "$failed_line" ]; then
    echo "$name: [Failed Assert] not found (check /workspace/${name}_detail.txt)" | tee -a /workspace/repro.txt
  else
    # Normalize: keep only the bracketed section or the number
    echo "$name: $failed_line" | tee -a /workspace/repro.txt
  fi

  # Small pause to avoid overlapping runs
  sleep 1
done

# Stop and remove container
docker stop "$container" >/dev/null
docker rm "$container" >/dev/null || true

# Section 4: Formatting and submission block
echo '<artisan_submit>' > /workspace/repro_submission.txt
cat /workspace/repro.txt >> /workspace/repro_submission.txt
echo '</artisan_submit>' >> /workspace/repro_submission.txt

echo "Reproduction finished. Results in /workspace/repro.txt and /workspace/repro_submission.txt"
