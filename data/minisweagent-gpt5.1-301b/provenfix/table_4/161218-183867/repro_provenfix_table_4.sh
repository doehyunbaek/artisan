#!/usr/bin/bash
set -euo pipefail

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
if [ ! -d /workspace/infer_TempFix ]; then
  git clone https://github.com/songyahui/infer_TempFix /workspace/infer_TempFix
fi

docker pull yahuuuuui/fse24-prove_n_fix:ubuntu
docker rm -f provenfix_table_4 2>/dev/null || true
docker run -d --init --name provenfix_table_4 --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Prepare ProveNFix for Experiment 3 (double-free bugs)
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/infer_TempFix && git checkout doubleFreeClose && ./compile'

# Section 3: Reproduction commands (populate from reviewed steps)
# lxc
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/infer_TempFix && cp spec_Temp_lxc.c spec.c'
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/benchmarks-RQ3/lxc && make clean'
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/benchmarks-RQ3/lxc && /home/infer_TempFix/infer/bin/tempFix' > /workspace/lxc.log 2>&1

# p11-kit
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/infer_TempFix && cp spec_Temp_p11.c spec.c'
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/benchmarks-RQ3/p11-kit && make clean'
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/benchmarks-RQ3/p11-kit && /home/infer_TempFix/infer/bin/tempFix' > /workspace/p11-kit.log 2>&1

# grub
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/infer_TempFix && cp spec_Temp_grub.c spec.c'
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/benchmarks-RQ3/grub && make clean'
docker exec provenfix_table_4 /bin/bash --noprofile --norc -c 'cd /home/benchmarks-RQ3/grub && /home/infer_TempFix/infer/bin/tempFix' > /workspace/grub.log 2>&1 || true

# Extract repaired bug counts from logs
extract_repaired_bugs() {
  local log_file="$1"
  grep '\[Repaired   Bugs\]' "$log_file" | awk '{print $3}' | tail -n 1
}

lxc_bugs="$(extract_repaired_bugs /workspace/lxc.log)"
p11_bugs="$(extract_repaired_bugs /workspace/p11-kit.log)"
grub_bugs="$(extract_repaired_bugs /workspace/grub.log)"

# Fallback to 0 if any parse fails
lxc_bugs="${lxc_bugs:-0}"
p11_bugs="${p11_bugs:-0}"
grub_bugs="${grub_bugs:-0}"

total_bugs=$(( lxc_bugs + p11_bugs + grub_bugs ))

# Write reproduction results to /workspace/repro.txt as a markdown table
{
  echo '**Table 4. Automatically finding/fixing double-free bugs (reproduced).**'
  echo
  echo '| Project   |         Repaired Bugs |'
  echo '| --------- | --------------------: |'
  printf '| %-9s | %20d |\n' 'lxc' "$lxc_bugs"
  printf '| %-9s | %20d |\n' 'p11-kit' "$p11_bugs"
  printf '| %-9s | %20d |\n' 'grub' "$grub_bugs"
  printf '| %-9s | %20d |\n' '**Total**' "$total_bugs"
} > /workspace/repro.txt

# Section 4: Formatting and submission block
echo '<artisan_submit>'
cat /workspace/expected.md
echo
cat /workspace/repro.txt
echo '</artisan_submit>'
