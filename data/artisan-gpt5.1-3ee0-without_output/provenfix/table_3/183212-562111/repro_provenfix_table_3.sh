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

# 3.1 Prepare Docker environment with ProveNFix
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker rm -f prove_n_fix 2>/dev/null || true
docker run -d --init --entrypoint bash --name prove_n_fix yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Build ProveNFix on the main branch
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && git reset --hard && git checkout main && ./compile"

# 3.2 Run ProveNFix on each project and capture logs
# Swoole
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Swoole.c spec.c && cd /home/benchmarks-RQ1N2/swoole-src && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/swoole_tempfix.log 2>&1" || true
# lxc
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Lxc.c spec.c && cd /home/benchmarks-RQ1N2/lxc && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/lxc_tempfix.log 2>&1" || true
# WavPack
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_WavPack.c spec.c && cd /home/benchmarks-RQ1N2/WavPack && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/wavpack_tempfix.log 2>&1" || true
# flex
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_flex.c spec.c && cd /home/benchmarks-RQ1N2/flex && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/flex_tempfix.log 2>&1" || true
# p11-kit
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_p11.c spec.c && cd /home/benchmarks-RQ1N2/p11-kit && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/p11kit_tempfix.log 2>&1" || true
# x264
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec-x264.c spec.c && cd /home/benchmarks-RQ1N2/x264 && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/x264_tempfix.log 2>&1" || true
# recutils-1.8
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec-recutils.c spec.c && cd /home/benchmarks-RQ1N2/recutils-1.8 && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/recutils_tempfix.log 2>&1" || true
# inetutils-1.9.4
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec-inetutils.c spec.c && cd /home/benchmarks-RQ1N2/inetutils-1.9.4 && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/inetutils_tempfix.log 2>&1" || true
# snort-2.9.13
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_snort-2.9.13.c spec.c && cd /home/benchmarks-RQ1N2/snort-2.9.13 && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/snort_tempfix.log 2>&1" || true
# grub
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Grub.c spec.c && cd /home/benchmarks-RQ1N2/grub && make clean && /home/infer_TempFix/infer/bin/tempFix > /tmp/grub_tempfix.log 2>&1" || true

# 3.3 Extract [Repaired   Bugs] counts from logs inside the container
swoole=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/swoole_tempfix.log | tail -n 1 | awk '{print \$4}'")
lxc=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/lxc_tempfix.log | tail -n 1 | awk '{print \$4}'")
wavpack=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/wavpack_tempfix.log | tail -n 1 | awk '{print \$4}'")
flex=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/flex_tempfix.log | tail -n 1 | awk '{print \$4}'")
p11=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/p11kit_tempfix.log | tail -n 1 | awk '{print \$4}'")
x264=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/x264_tempfix.log | tail -n 1 | awk '{print \$4}'")
recutils=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/recutils_tempfix.log | tail -n 1 | awk '{print \$4}'")
inetutils=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/inetutils_tempfix.log | tail -n 1 | awk '{print \$4}'")
snort=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/snort_tempfix.log | tail -n 1 | awk '{print \$4}'")
grub=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "grep '\[Repaired   Bugs\]' /tmp/grub_tempfix.log | tail -n 1 | awk '{print \$4}'")

total=$((swoole + lxc + wavpack + flex + p11 + x264 + recutils + inetutils + snort + grub))

# 3.4 Construct the reproduced Table 3 from the extracted numbers
cat > /workspace/repro.txt <<EOREPRO
**Table 3. Experimental results for repairing 10 C projects, comparing with SAVER and FootPatch. Columns marked as # are numbers of the total true positives found by Infer-v1.1.0 and PROVENFIX, summarised from Table 2. The numbers of false positives reported by Infer-v0.9.3 are marked as +n.**

| Project         | Repaired Bugs |
| --------------- | ------------: |
| Swoole          | $swoole |
| lxc             | $lxc |
| WavPack         | $wavpack |
| flex            | $flex |
| p11-kit         | $p11 |
| x264            | $x264 |
| recutils-1.8    | $recutils |
| inetutils-1.9.4 | $inetutils |
| snort-2.9.13    | $snort |
| grub            | $grub |
| **Total**       |       **$total** |

EOREPRO

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
