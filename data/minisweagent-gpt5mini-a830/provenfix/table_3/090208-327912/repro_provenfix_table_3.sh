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

# Section 2: Artifact download and container setup
# Ensure repository is present
git clone https://github.com/songyahui/infer_TempFix /workspace/infer_TempFix || true

# Pull and (re)start the provided docker image as a sleeping container for exec usage
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker rm -f prove_n_fix_container || true
docker run -d --init --entrypoint bash --name prove_n_fix_container yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Section 3: Reproduction commands (populate from reviewed steps)
# This will sequentially run ProveNFix for each benchmark and append outputs to /workspace/repro.txt
: > /workspace/repro.txt

echo "=== Reproduction of Table 3: ProveNFix runs ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Swoole.c spec.c && cd /home/benchmarks-RQ1N2/swoole-src && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End Swoole ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Lxc.c spec.c && cd /home/benchmarks-RQ1N2/lxc && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End lxc ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_WavPack.c spec.c && cd /home/benchmarks-RQ1N2/WavPack && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End WavPack ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_flex.c spec.c && cd /home/benchmarks-RQ1N2/flex && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End flex ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_p11.c spec.c && cd /home/benchmarks-RQ1N2/p11-kit && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End p11-kit ===" >> /workspace/repro.txt

# Note: spec file for x264 uses a hyphen in the artifact docs
docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec-x264.c spec.c && cd /home/benchmarks-RQ1N2/x264 && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End x264 ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec-recutils.c spec.c && cd /home/benchmarks-RQ1N2/recutils-1.8 && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End recutils-1.8 ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec-inetutils.c spec.c && cd /home/benchmarks-RQ1N2/inetutils-1.9.4 && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End inetutils-1.9.4 ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_snort-2.9.13.c spec.c && cd /home/benchmarks-RQ1N2/snort-2.9.13 && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End snort-2.9.13 ===" >> /workspace/repro.txt

docker exec prove_n_fix_container /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Grub.c spec.c && cd /home/benchmarks-RQ1N2/grub && make clean || true && /home/infer_TempFix/infer/bin/tempFix" >> /workspace/repro.txt 2>&1
echo "=== End grub ===" >> /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'

