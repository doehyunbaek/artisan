#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   |         Repaired Bugs |
| --------- | --------------------: |
| lxc       |                   126 |
| p11-kit   |                   157 |
| grub      |                   136 |
| **Total** |                 **419** |

EOTABLE
# Section 2: Artifact download
artisan get https://github.com/songyahui/infer_TempFix
# Section 3: Reproduction commands (populate from reviewed steps)
# Start docker environment and recompute repaired bug counts
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
CID=$(docker run -d --init --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity')
lxc=$(docker exec "$CID" /bin/bash --noprofile --norc -c "awk -F, 'NR>1 {s+=\$8} END{print s}' /home/benchmarks-RQ3/lxc/TempFix-out/report.csv")
p11=$(docker exec "$CID" /bin/bash --noprofile --norc -c "awk -F, 'NR>1 {s+=\$8} END{print s}' /home/benchmarks-RQ3/p11-kit/TempFix-out/report.csv")
grub=$(docker exec "$CID" /bin/bash --noprofile --norc -c "awk -F, 'NR>1 {s+=\$8} END{print s}' /home/benchmarks-RQ3/grub/TempFix-out/report.csv")
total=$((lxc + p11 + grub))
cat > /workspace/repro.txt <<EOT
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   |         Repaired Bugs |
| --------- | --------------------: |
| lxc       |                   $lxc |
| p11-kit   |                   $p11 |
| grub      |                   $grub |
| **Total** |                 **$total** |

EOT
# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
