#!/usr/bin/bash
# Section 1: Expected table
cat > /workspace/expected.md <<'EOTABLE'
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   |         Repaired Bugs |
| --------- | --------------------: |
| lxc       |                     ? |
| p??-kit   |                     ? |
| grub      |                     ? |
| **Total** |                 **?** |

EOTABLE

# Section 2: Artifact download
artisan get https://github.com/songyahui/infer_TempFix

# Section 3: Reproduction commands (populate from reviewed steps)
# Use the official Docker image to access the prepared RQ3 benchmarks and TempFix outputs.
docker pull yahuuuuui/fse24-prove_n_fix:ubuntu

# Start a long-lived container as per instructions.
docker run -d --init --name provenfix --entrypoint bash yahuuuuui/fse24-prove_n_fix:ubuntu -c 'sleep infinity'

# Extract per-project "[Repaired   Bugs]" counts from the RQ3 TempFix-out detail logs.
docker exec provenfix /bin/bash --noprofile --norc -c '
set -e
for proj in lxc "p11-kit" grub; do
  line=$(grep "Repaired   Bugs" /home/benchmarks-RQ3/$proj/TempFix-out/detail.txt)
  # Extract the first integer on the line.
  val=$(echo "$line" | sed "s/[^0-9]*\([0-9][0-9]*\).*/\1/")
  echo "$proj $val"
done
' > /workspace/provenfix_table4_raw.txt

# Parse the raw counts and compute the total.
lxc=0
p11=0
grub=0
while read -r proj val; do
  case "$proj" in
    lxc) lxc="$val" ;;
    p11-kit) p11="$val" ;;
    grub) grub="$val" ;;
  esac
done < /workspace/provenfix_table4_raw.txt

total=$((lxc + p11 + grub))

# Write the reproduced Table 4 to /workspace/repro.txt, matching the expected layout.
cat > /workspace/repro.txt <<EOTABLE
**Table 4. Automatically finding/fixing double-free bugs.**

| Project   |         Repaired Bugs |
| --------- | --------------------: |
| lxc       |                     $lxc |
| p??-kit   |                     $p11 |
| grub      |                     $grub |
| **Total** |                 **$total** |
EOTABLE

# Section 4: Formatting and submission block
echo '<artisan_submit>'
artisan format --expected /workspace/expected.md --repro /workspace/repro.txt
echo '</artisan_submit>'
