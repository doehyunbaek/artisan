#!/usr/bin/bash
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

# Section 2: Artifact download
cd /workspace
artisan get https://github.com/songyahui/infer_TempFix

# Section 3: Reproduction commands
# Use the official ProveNFix Docker image that contains the benchmarks and tool outputs
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker run -d --init --entrypoint bash --name prove_n_fix_table2 yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Helper: extract [Failed Assert] from each project's TempFix-out/detail.txt inside the container
swoole=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/swoole-src/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
lxc=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/lxc/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
wavpack=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/WavPack/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
flex=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/flex/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
p11=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/p11-kit/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
x264=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/x264/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
recutils=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/recutils-1.8/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
inetutils=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/inetutils-1.9.4/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
snort=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/snort-2.9.13/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')
grub=$(docker exec prove_n_fix_table2 /bin/bash --noprofile --norc -c 'grep "\[Failed Assert\]" /home/benchmarks-RQ1N2/grub/TempFix-out/detail.txt | head -n1 | awk "{print \$3}"')

total=$((swoole + lxc + wavpack + flex + p11 + x264 + recutils + inetutils + snort + grub))

cat > /workspace/repro.txt <<EOREPRO
**Table 2. Experimental results for analyzing 10 C projects, comparing with Infer-v1.1.0. Columns **#NPD**, **#ML**, **#RL** record the numbers of null pointer dereferences, memory leaks, and resource leaks, respectively. The number of false positives found by Infer and more true positives found by PROVENFIX are represented by +n and +n respectively. Colunns in #Time record the analysis time spent.**

| Project         | Failed Assert |
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
