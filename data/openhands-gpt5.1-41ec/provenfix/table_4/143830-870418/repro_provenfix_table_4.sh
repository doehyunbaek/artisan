#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   |         Repaired Bugs |
| --------- | --------------------: |
| lxc       |                     0 |
| p11-kit   |                     4 |
| grub      |                     5 |
| **Total** |                 **9** |

EOTABLE
# Section 2: Artifact download
cd /workspace
if [ ! -d infer_TempFix ]; then
  git clone https://github.com/songyahui/infer_TempFix.git
fi
# Section 3: Reproduction commands (populate from reviewed steps)
# Use the Docker image recommended by the artifact authors
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
# Start a long-running container for all experiments
docker rm -f prove_n_fix >/dev/null 2>&1 || true
docker run -d --init --name prove_n_fix --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'
# Checkout the doubleFreeClose branch and compile ProveNFix
docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && git reset --hard && git checkout doubleFreeClose && ./compile"
# Run Experiment 3 (Table 4) for each project sequentially
# lxc
LXC_REPAIRED=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Temp_lxc.c spec.c && cd /home/benchmarks-RQ3/lxc && make clean && /home/infer_TempFix/infer/bin/tempFix" | awk '/\[Repaired/{print $3}' | tail -n1)
# p11-kit
P11_REPAIRED=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Temp_p11.c spec.c && cd /home/benchmarks-RQ3/p11-kit && make clean && /home/infer_TempFix/infer/bin/tempFix" | awk '/\[Repaired/{print $3}' | tail -n1)
# grub
GRUB_REPAIRED=$(docker exec prove_n_fix /bin/bash --noprofile --norc -c "cd /home/infer_TempFix && cp spec_Temp_grub.c spec.c && cd /home/benchmarks-RQ3/grub && make clean && /home/infer_TempFix/infer/bin/tempFix" | awk '/\[Repaired/{print $3}' | tail -n1)
# Compute total repaired bugs
TOTAL_REPAIRED=$((LXC_REPAIRED + P11_REPAIRED + GRUB_REPAIRED))
# Write reproduction results table to /workspace/repro.txt
cat > /workspace/repro.txt <<EOTABLE
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   | Repaired Bugs |
| --------- | -------------:|
| lxc       | ${LXC_REPAIRED} |
| p11-kit   | ${P11_REPAIRED} |
| grub      | ${GRUB_REPAIRED} |
| **Total** | **${TOTAL_REPAIRED}** |

EOTABLE
# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/repro.txt
echo '</artisan_submit>'
